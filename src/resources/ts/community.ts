export {};
type AccountState={token:string;suggestion:string;user:{name:string;kind:string}|null;admin:boolean};
type Comment={id:string;name:string;role:string;parent:string;root:string;body:string;date:string;deleted:boolean;can_delete:boolean};
const dialog=document.querySelector<HTMLDialogElement>("#account-dialog");
if(dialog&&!document.querySelector("#studio")){
const accountDialog:HTMLDialogElement=dialog;
let state:AccountState|undefined,mode="signup",page=1,reply="",totalRoots=0;
let bookmarks=new Set<string>(), pendingBookmark="";
const savedView=location.pathname==="/bookmarks";
const accountForm=document.querySelector<HTMLFormElement>("#account-form")!;
const credentialsForm=document.querySelector<HTMLFormElement>("#credentials-form")!;
const thread=document.querySelector<HTMLElement>("#post-comments");
const post=thread?.dataset.postId??"";
const questionThread=thread?.hasAttribute("data-community-question")??false;
const commentBase=thread?.dataset.commentBase??`/community/posts/${encodeURIComponent(post)}/comments`;
const commentForm=document.querySelector<HTMLFormElement>("#comment-form");
const commentBody=document.querySelector<HTMLTextAreaElement>("#comment-body");
const status=document.querySelector<HTMLElement>("#comments-message");
function saved(key:string){try{return localStorage.getItem(key);}catch{return null;}}
function save(key:string,value:string){try{localStorage.setItem(key,value);}catch{}}
function formMessage(form:Element,text:string,success=false){const message=form.querySelector<HTMLElement>(".form-message")!;message.textContent=text;message.classList.toggle("success",success);}
async function request(path:string,fields?:URLSearchParams){const response=await fetch(path,{method:fields?"POST":"GET",headers:fields?{"Content-Type":"application/x-www-form-urlencoded","X-Community-Token":state?.token??""}:{},body:fields,cache:"no-store"});const data=await response.json();if(!response.ok)throw new Error(data.message??"Could not complete the request.");return data;}
function field(form:HTMLFormElement,name:string){return form.elements.namedItem(name) as HTMLInputElement|HTMLSelectElement;}
function credentialRules(){const secret=field(accountForm,"secret") as HTMLInputElement;secret.minLength=6;secret.maxLength=12;secret.inputMode="numeric";secret.pattern="[0-9]{6,12}";document.querySelector("#credential-label")!.textContent=mode==="login"?"Your PIN":"Choose a PIN (6–12 digits)";secret.autocomplete=mode==="login"?"current-password":"new-password";}
function switchMode(next:string){mode=next;const signup=mode==="signup";for(const tab of document.querySelectorAll<HTMLElement>("[data-account-tab]")){tab.classList.toggle("active",tab.dataset.accountTab===mode);tab.setAttribute("aria-pressed",String(tab.dataset.accountTab===mode));}document.querySelector<HTMLElement>("#generated-name")!.hidden=!signup;document.querySelector<HTMLElement>("#login-name-field")!.hidden=signup;document.querySelector<HTMLElement>("#confirm-secret-field")!.hidden=!signup;field(accountForm,"confirm_secret").required=signup;field(accountForm,"name").required=!signup;field(accountForm,"secret").value="";field(accountForm,"confirm_secret").value="";document.querySelector("#account-submit")!.textContent=signup?"Create account & sign in":"Sign in";accountForm.action=signup?"/community/signup":"/community/login";document.querySelector("#account-heading")!.textContent=signup?"Join the conversation":"Welcome back";document.querySelector("#account-hint")!.textContent=signup?"Save your username. You’ll need it with your PIN to sign in on another device.":"Use the generated username and PIN you saved.";formMessage(accountForm,"");credentialRules();}
function hydrate(){if(!state)return;document.querySelector("#suggested-name")!.textContent=state.suggestion;accountForm.hidden=Boolean(state.user);document.querySelector<HTMLElement>(".account-tabs")!.hidden=Boolean(state.user);document.querySelector<HTMLElement>("#account-profile")!.hidden=!state.user;if(state.user){document.querySelector("#account-name")!.textContent=state.user.name;document.querySelector("#account-heading")!.textContent="Your account";save("devnotes.username",state.user.name);}for(const button of document.querySelectorAll<HTMLElement>("[data-account-open]")){button.textContent=state.user?.name??(state.admin?"Author account":"Join / Sign in");button.title=state.user?"Manage your account":"Create an account or sign in";}const identity=document.querySelector("#comment-identity");if(identity)identity.textContent=state.admin&&!questionThread?"Replying as the post author · Creator Studio":state.user?`Commenting as ${state.user.name}`:"Create an account or sign in to join the conversation.";}
function openAccount(){hydrate();if(!state?.user)switchMode(saved("devnotes.username")?"login":"signup");if(!accountDialog.open)accountDialog.showModal();}
function closeAccount(){save("devnotes.accountPrompt","seen");accountDialog.close();accountForm.reset();credentialsForm.reset();credentialRules();}
for(const button of document.querySelectorAll("[data-account-open]"))button.addEventListener("click",openAccount);
for(const button of document.querySelectorAll("[data-account-close]"))button.addEventListener("click",closeAccount);
accountDialog.addEventListener("cancel",()=>{save("devnotes.accountPrompt","seen");accountForm.reset();credentialsForm.reset();});
for(const tab of document.querySelectorAll<HTMLElement>("[data-account-tab]"))tab.addEventListener("click",()=>switchMode(tab.dataset.accountTab??"signup"));
field(accountForm,"name").value=saved("devnotes.username")??"";
document.querySelector<HTMLButtonElement>("[data-generate-name]")!.addEventListener("click",async(event)=>{const button=event.currentTarget as HTMLButtonElement;button.disabled=true;try{state=await request("/community/name",new URLSearchParams());hydrate();}catch(error){formMessage(accountForm,(error as Error).message);}finally{button.disabled=false;}});
function validateCredentials(form:HTMLFormElement){const secret=field(form,"secret").value;const confirm=field(form,"confirm_secret").value;if(secret!==confirm)throw new Error("PIN confirmation does not match.");if(!/^[0-9]{6,12}$/.test(secret))throw new Error("Choose a PIN with 6–12 digits.");}
accountForm.addEventListener("submit",async(event)=>{event.preventDefault();const button=document.querySelector<HTMLButtonElement>("#account-submit")!;button.disabled=true;try{if(mode==="signup")validateCredentials(accountForm);const fields=new URLSearchParams();for(const [key,value]of new FormData(accountForm))if(key!=="confirm_secret")fields.set(key,String(value));state=await request(`/community/${mode}`,fields);hydrate();closeAccount();await loadBookmarks();if(pendingBookmark){const id=pendingBookmark;pendingBookmark="";await setBookmark(id,true);}if(savedView){location.reload();return;}if(post)await loadComments();}catch(error){formMessage(accountForm,(error as Error).message);}finally{button.disabled=false;}});
credentialsForm.addEventListener("submit",async(event)=>{event.preventDefault();const button=credentialsForm.querySelector<HTMLButtonElement>("button[type=submit]")!;button.disabled=true;try{validateCredentials(credentialsForm);const fields=new URLSearchParams();for(const[key,value]of new FormData(credentialsForm))if(key!=="confirm_secret")fields.set(key,String(value));await request("/community/credentials",fields);credentialsForm.reset();state=await request("/community/session");hydrate();formMessage(credentialsForm,"PIN updated.",true);}catch(error){formMessage(credentialsForm,(error as Error).message);}finally{button.disabled=false;}});
document.querySelector<HTMLButtonElement>("[data-account-logout]")!.addEventListener("click",async(event)=>{const button=event.currentTarget as HTMLButtonElement;button.disabled=true;try{state=await request("/community/logout",new URLSearchParams());credentialsForm.reset();hydrate();switchMode("login");field(accountForm,"name").value=saved("devnotes.username")??"";await loadBookmarks();if(savedView){location.reload();return;}if(post)await loadComments();}catch(error){formMessage(credentialsForm,(error as Error).message);}finally{button.disabled=false;}});

function notice(text:string){const toast=document.createElement("div");toast.className="toast";toast.setAttribute("role","status");toast.textContent=text;document.body.append(toast);setTimeout(()=>toast.remove(),2400);}
function paintBookmarks(){
  for(const button of document.querySelectorAll<HTMLButtonElement>("[data-bookmark]")){
    const saved=bookmarks.has(button.dataset.bookmark??"");const title=button.dataset.bookmarkTitle??"post";
    button.setAttribute("aria-pressed",String(saved));button.setAttribute("aria-label",saved?`Remove ${title} from saved posts`:`Save ${title}`);button.title=saved?"Remove bookmark":"Save for later";
    const label=button.querySelector("[data-bookmark-label]");if(label)label.textContent=saved?"Saved":"Save";
  }
  for(const card of document.querySelectorAll<HTMLElement>("[data-post]")){const id=card.querySelector<HTMLElement>("[data-bookmark]")?.dataset.bookmark??"";card.dataset.saved=String(bookmarks.has(id));}
  for(const count of document.querySelectorAll("[data-bookmark-count]"))count.textContent=String(bookmarks.size);
  const savedStatus=document.querySelector("#saved-status");if(savedStatus)savedStatus.textContent=state?.user?`${bookmarks.size} saved ${bookmarks.size===1?"post":"posts"} · ${state.user.name}`:"Sign in to see your saved articles and videos.";
  if(savedView){document.querySelector("#empty-heading")!.textContent=state?.user?"No matching saved posts":"Your saved posts live here";document.querySelector("#empty-description")!.textContent=state?.user?"Save articles or videos with the bookmark button, or clear your filters.":"Sign in to save posts and find them again on any device.";}
  window.dispatchEvent(new Event("bookmarks:changed"));
}
async function loadBookmarks(){
  if(!state?.user){bookmarks.clear();paintBookmarks();return;}
  const entries:{id:string}[]=await request("/community/bookmarks");bookmarks=new Set(entries.map(entry=>entry.id));paintBookmarks();
}
async function setBookmark(id:string,saved:boolean){
  const entries:{id:string}[]=await request(`/community/bookmarks/${encodeURIComponent(id)}`,new URLSearchParams({saved:saved?"yes":"no"}));bookmarks=new Set(entries.map(entry=>entry.id));paintBookmarks();notice(saved?"Saved to bookmarks":"Removed from saved posts");
}
for(const button of document.querySelectorAll<HTMLButtonElement>("[data-bookmark]"))button.addEventListener("click",async()=>{
  const id=button.dataset.bookmark??"";if(!state?.user){pendingBookmark=id;openAccount();return;}
  button.disabled=true;try{await setBookmark(id,!bookmarks.has(id));}catch(error){notice((error as Error).message);}finally{button.disabled=false;}
});

function cancelReply(){reply="";document.querySelector<HTMLElement>("#reply-target")!.hidden=true;commentForm?.querySelector<HTMLButtonElement>("button[type=submit]")?.replaceChildren(document.createTextNode("Comment"));}
document.querySelector("#reply-cancel")?.addEventListener("click",cancelReply);
function node<K extends keyof HTMLElementTagNameMap>(tag:K,className:string,text?:string){const n=document.createElement(tag);n.className=className;if(text)n.textContent=text;return n;}
function renderComment(comment:Comment,all:Comment[]):HTMLElement{
 const item=node("article","comment-item"+(comment.parent?" comment-reply":""));
 const avatar=node("span","comment-avatar",comment.role==="author"&&!questionThread?"":comment.name.slice(0,1).toUpperCase());
 if(comment.role==="author"&&!questionThread){const mark=document.createElement("img");mark.src="/static/images/sourcecat-solid.png";mark.className="sourcecat-mark";mark.alt="";avatar.append(mark);}
 const content=node("div","comment-content");const head=node("div","comment-meta");head.append(node("strong","",comment.name));if(comment.role==="author")head.append(node("span","author-badge",questionThread?"Question author":"Author"));const date=node("time","",new Date(comment.date).toLocaleString(undefined,{dateStyle:"medium",timeStyle:"short"}));date.dateTime=comment.date;head.append(date);content.append(head);
 if(comment.parent){const parent=all.find(c=>c.id===comment.parent);if(parent)content.append(node("small","reply-to",`↳ Reply to ${parent.name}`));}
 content.append(node("p",comment.deleted?"comment-text comment-deleted":"comment-text",comment.deleted?"This comment was removed.":comment.body));
 const actions=node("div","comment-actions");if(!comment.deleted){const replyButton=node("button","","Reply");replyButton.type="button";replyButton.addEventListener("click",()=>{if(!state?.user&&(!state?.admin||questionThread)){openAccount();return;}reply=comment.id;document.querySelector<HTMLElement>("#reply-target")!.hidden=false;document.querySelector("#reply-target span")!.textContent=`Replying to ${comment.name}`;commentForm!.querySelector<HTMLButtonElement>("button[type=submit]")!.textContent="Post reply";commentBody?.focus();commentForm?.scrollIntoView({behavior:"smooth",block:"center"});});actions.append(replyButton);}
 if(comment.can_delete){const button=node("button","comment-delete","Delete");button.type="button";button.addEventListener("click",async()=>{if(!window.confirm("Delete this comment? Replies will remain."))return;button.disabled=true;try{await request(`/community/comments/${encodeURIComponent(comment.id)}/delete`,new URLSearchParams());await loadComments();}catch(error){status!.textContent=(error as Error).message;}finally{button.disabled=false;}});actions.append(button);}
 content.append(actions);item.append(avatar,content);return item;
}
async function loadComments(){if(!post)return;try{const data:{comments:Comment[];roots:number;total:number}=await request(`${commentBase}/${page}`);totalRoots=data.roots;const maxPage=Math.max(1,Math.ceil(totalRoots/10));if(page>maxPage){page=maxPage;return await loadComments();}document.querySelector("#comment-count")!.textContent=String(data.total);const list=document.querySelector<HTMLElement>("#comment-list")!;list.replaceChildren();const roots=data.comments.filter(c=>!c.parent).reverse();for(const root of roots){const group=node("div","comment-thread");group.append(renderComment(root,data.comments));for(const child of data.comments.filter(c=>c.root===root.id&&c.parent))group.append(renderComment(child,data.comments));list.append(group);}status!.textContent=totalRoots?"":questionThread?"Be the first to help with this question.":"Start the conversation. What did you learn?";const pagination=document.querySelector<HTMLElement>(".comments-pagination")!;pagination.hidden=maxPage<=1;document.querySelector<HTMLButtonElement>("#comments-prev")!.disabled=page<=1;document.querySelector<HTMLButtonElement>("#comments-next")!.disabled=page>=maxPage;document.querySelector("#comments-page")!.textContent=`Page ${page} of ${maxPage}`;}catch(error){status!.textContent=(error as Error).message;}}
document.querySelector("#comments-prev")?.addEventListener("click",()=>{page--;loadComments();});
document.querySelector("#comments-next")?.addEventListener("click",()=>{page++;loadComments();});
commentForm?.addEventListener("submit",async(event)=>{event.preventDefault();if(!state?.user&&(!state?.admin||questionThread)){openAccount();return;}const button=commentForm.querySelector<HTMLButtonElement>("button[type=submit]")!;button.disabled=true;try{await request(commentBase,new URLSearchParams({body:commentBody!.value,parent:reply}));if(!reply)page=1;commentBody!.value="";cancelReply();formMessage(commentForm,"Posted. Thanks for joining the conversation.",true);await loadComments();}catch(error){formMessage(commentForm,(error as Error).message);}finally{button.disabled=false;}});

const questionDialog=document.querySelector<HTMLDialogElement>("#question-dialog");
const questionForm=document.querySelector<HTMLFormElement>("#question-form");
document.querySelector("#ask-question")?.addEventListener("click",()=>{if(!state?.user){openAccount();return;}questionDialog?.showModal();});
document.querySelector("#question-close")?.addEventListener("click",()=>questionDialog?.close());
questionForm?.addEventListener("submit",async(event)=>{event.preventDefault();if(!state?.user){questionDialog?.close();openAccount();return;}const button=questionForm.querySelector<HTMLButtonElement>("button[type=submit]")!;button.disabled=true;try{const fields=new URLSearchParams();for(const[key,value]of new FormData(questionForm))fields.set(key,String(value));const data=await request("/community/questions",fields);location.assign(data.url);}catch(error){formMessage(questionForm,(error as Error).message);}finally{button.disabled=false;}});
const questionSearch=document.querySelector<HTMLInputElement>("#question-search");
const questionTopic=document.querySelector<HTMLSelectElement>("#question-topic");
const questionCards=[...document.querySelectorAll<HTMLElement>("[data-question-search]")];
for(const time of document.querySelectorAll<HTMLTimeElement>(".question-meta time")){const date=new Date(time.textContent??"");if(!Number.isNaN(date.getTime())){time.dateTime=date.toISOString();time.textContent=date.toLocaleDateString(undefined,{dateStyle:"medium"});}}
let questionPage=1;
function filterQuestions(){if(!questionSearch||!questionTopic)return;const query=questionSearch.value.trim().toLocaleLowerCase();const matches=questionCards.filter(card=>(card.dataset.questionSearch??"").toLocaleLowerCase().includes(query)&&(questionTopic.value==="all"||card.dataset.questionTopic===questionTopic.value));const pages=Math.max(1,Math.ceil(matches.length/10));questionPage=Math.min(questionPage,pages);for(const card of questionCards)card.hidden=true;for(const card of matches.slice((questionPage-1)*10,questionPage*10))card.hidden=false;document.querySelector("#questions-status")!.textContent=matches.length?`${matches.length} ${matches.length===1?"question":"questions"} · Everyone can read. Sign in to participate.`:"No questions yet. Ask a question or try another search.";document.querySelector("#questions-page")!.textContent=`Page ${questionPage} of ${pages}`;document.querySelector<HTMLButtonElement>("#questions-prev")!.disabled=questionPage===1;document.querySelector<HTMLButtonElement>("#questions-next")!.disabled=questionPage===pages;document.querySelector<HTMLElement>("#questions-pagination")!.hidden=pages<=1;}
if(questionTopic){for(const topic of [...new Set(questionCards.map(card=>card.dataset.questionTopic??""))].sort()){const option=document.createElement("option");option.value=topic;option.textContent=topic;questionTopic.append(option);}filterQuestions();}
questionSearch?.addEventListener("input",()=>{questionPage=1;filterQuestions();});
questionTopic?.addEventListener("change",()=>{questionPage=1;filterQuestions();});
document.querySelector("#questions-prev")?.addEventListener("click",()=>{questionPage--;filterQuestions();});
document.querySelector("#questions-next")?.addEventListener("click",()=>{questionPage++;filterQuestions();});
(async()=>{try{state=await request("/community/session");hydrate();await loadBookmarks();if(post)await loadComments();if((savedView&&!state?.user)||(!location.pathname.startsWith("/community")&&!state?.user&&(!state?.admin||questionThread)&&!saved("devnotes.accountPrompt")))openAccount();}catch(error){if(status)status.textContent=(error as Error).message;formMessage(accountForm,"Could not connect. Refresh the page to try again.");}})();
}
