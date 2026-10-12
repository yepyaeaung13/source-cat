import {loadRichEditors,syncRichEditors} from "./richtext";
type Entry={id:string;kind:string;title:string;category:string;excerpt:string;body:string;youtube:string;creator:string;thumbnail:string;status:string;date:string;minutes:string};
const studio=document.querySelector<HTMLElement>("#studio");
const token=studio?.dataset.token??"";
async function request(path:string,fields?:URLSearchParams){const response=await fetch(path,{method:fields?"POST":"GET",headers:fields?{"X-Studio-Token":token,"Content-Type":"application/x-www-form-urlencoded"}:{},body:fields});const data=await response.json();if(!response.ok)throw new Error(data.message??"Request failed");return data;}
function message(root:Element,text:string,success=false){const node=root.querySelector<HTMLElement>(".form-message");if(node){node.textContent=text;node.classList.toggle("success",success);}}
const login=document.querySelector<HTMLFormElement>("#login-form");
login?.addEventListener("submit",async(event)=>{event.preventDefault();const button=login.querySelector<HTMLButtonElement>("button")!;button.disabled=true;try{await request("/admin/login",new URLSearchParams({password:String(new FormData(login).get("password")??"")}));location.reload();}catch(error){message(login,(error as Error).message);}finally{button.disabled=false;}});
document.querySelector("[data-logout]")?.addEventListener("click",async()=>{try{await request("/admin/logout",new URLSearchParams());location.reload();}catch(error){alert((error as Error).message);}});
const form=document.querySelector<HTMLFormElement>("#editor-form");
if(form){
const editorForm:HTMLFormElement=form;
let entries:Entry[]=[],status="all",pendingDelete="",dirty=false,page=1;
const kindFilter=document.querySelector<HTMLSelectElement>("#studio-kind")!;
const topicFilter=document.querySelector<HTMLSelectElement>("#studio-topic")!;
const pageSize=document.querySelector<HTMLSelectElement>("#page-size")!;
const searchInput=document.querySelector<HTMLInputElement>("#studio-search")!;
const previous=document.querySelector<HTMLButtonElement>("#page-prev")!;
const next=document.querySelector<HTMLButtonElement>("#page-next")!;
const rows=document.querySelector<HTMLTableSectionElement>("#content-rows")!;
const editor=document.querySelector<HTMLElement>("#editor-panel")!;
const content=document.querySelector<HTMLElement>("#content-panel")!;
const dialog=document.querySelector<HTMLDialogElement>("#delete-dialog")!;
const input=(name:string)=>editorForm.elements.namedItem(name) as HTMLInputElement|HTMLTextAreaElement|HTMLSelectElement;
const studioMessage=document.querySelector<HTMLElement>("#studio-message")!;
function typeFields(){const video=input("kind").value==="video";document.querySelector<HTMLElement>("#body-field")!.hidden=false;document.querySelector<HTMLElement>("#youtube-field")!.hidden=!video;document.querySelector<HTMLElement>("#minutes-field")!.hidden=video;input("body").required=false;input("youtube").required=video;}
function escape(text:string){const node=document.createElement("span");node.textContent=text;return node.innerHTML.replace(/"/g,"&quot;");}
function safeImage(entry:Entry){if(entry.thumbnail.startsWith("https://"))return entry.thumbnail;if(entry.kind==="video"&&/^[\w-]{11}$/.test(entry.youtube))return `https://i.ytimg.com/vi/${entry.youtube}/hqdefault.jpg`;return "";}
function render(){const query=searchInput.value.trim().normalize().toLocaleLowerCase();const filtered=entries.filter(e=>(status==="all"||e.status===status)&&(kindFilter.value==="all"||e.kind===kindFilter.value)&&(topicFilter.value==="all"||e.category===topicFilter.value)&&`${e.title} ${e.category} ${e.id} ${e.creator}`.normalize().toLocaleLowerCase().includes(query));const size=Number(pageSize.value);const pages=Math.max(1,Math.ceil(filtered.length/size));page=Math.min(Math.max(1,page),pages);const start=(page-1)*size;const visible=filtered.slice(start,start+size);previous.disabled=page<=1;next.disabled=page>=pages;document.querySelector("#page-summary")!.textContent=filtered.length?`${start+1}–${start+visible.length} of ${filtered.length} posts`:"0 posts";document.querySelector("#page-number")!.textContent=`Page ${page} of ${pages}`;rows.replaceChildren();for(const entry of visible){const row=document.createElement("tr");const image=safeImage(entry);row.innerHTML=`<td><div class="table-content">${image?`<img class="table-thumbnail" src="${escape(image)}" alt="" loading="lazy">`:'<span class="table-thumbnail table-placeholder"><i data-lucide="file-text" aria-hidden="true"></i></span>'}<div><strong>${escape(entry.title)}</strong><small>${entry.kind==="video"?"YouTube video":"Article"} · ${escape(entry.id)}</small></div></div></td><td><span class="status-pill ${entry.status==="published"?"published":""}">${escape(entry.status)}</span></td><td>${escape(entry.category)}</td><td>${escape(entry.date)}</td><td><div class="row-actions"><button data-edit>Edit</button><button class="delete-action" data-delete>Delete</button></div></td>`;row.querySelector("[data-edit]")?.addEventListener("click",()=>openEditor(entry));row.querySelector("[data-delete]")?.addEventListener("click",()=>{pendingDelete=entry.id;document.querySelector("#delete-title")!.textContent=entry.title;message(dialog,"");dialog.showModal();});rows.append(row);}document.querySelector<HTMLElement>("#studio-empty")!.hidden=visible.length!==0;document.querySelector("#count-all")!.textContent=String(entries.length);document.querySelector("#count-published")!.textContent=String(entries.filter(e=>e.status==="published").length);document.querySelector("#count-drafts")!.textContent=String(entries.filter(e=>e.status==="draft").length);}
async function load(){try{entries=await request("/admin/content");const selected=topicFilter.value;topicFilter.replaceChildren(new Option("All topics","all"));for(const topic of [...new Set([...entries.map(e=>e.category),"Crash Course"])].sort())topicFilter.add(new Option(topic,topic));topicFilter.value=[...topicFilter.options].some(o=>o.value===selected)?selected:"all";render();}catch(error){studioMessage.textContent=(error as Error).message;}}
function abandon(){return !dirty||window.confirm("Discard your unsaved changes?");}
function openEditor(entry?:Entry){if(!abandon())return;editorForm.reset();for(const name of ["id","kind","title","category","excerpt","body","youtube","creator","thumbnail","status","date","minutes"]){input(name).value=entry?.[name as keyof Entry]??({kind:"article",creator:"SourceCat",status:"draft",date:new Date().toLocaleDateString("en-CA"),minutes:"5 min read"} as Record<string,string>)[name]??"";}input("original_id").value=entry?.id??"";(input("id") as HTMLInputElement).readOnly=Boolean(entry);if(entry){const parsed=new Date(entry.date);if(!Number.isNaN(parsed.valueOf()))input("date").value=parsed.toISOString().slice(0,10);}document.querySelector("#editor-title")!.textContent=entry?"Edit post":"Create a post";const view=document.querySelector<HTMLAnchorElement>("#editor-view")!;view.hidden=!entry||entry.status!=="published";if(entry)view.href=`/posts/${encodeURIComponent(entry.id)}`;typeFields();loadRichEditors();content.hidden=true;editor.hidden=false;message(editorForm,"");dirty=false;window.scrollTo(0,0);input("title").focus();}
function showList(){if(!abandon())return;dirty=false;content.hidden=false;editor.hidden=true;load();}
for(const button of document.querySelectorAll("[data-new]"))button.addEventListener("click",()=>openEditor());
for(const button of document.querySelectorAll("[data-studio-list]"))button.addEventListener("click",showList);
editorForm.addEventListener("input",()=>{dirty=true;});
input("kind").addEventListener("change",typeFields);
for(const button of document.querySelectorAll<HTMLElement>("[data-status]"))button.addEventListener("click",()=>{status=button.dataset.status??"all";page=1;for(const tab of document.querySelectorAll<HTMLElement>("[data-status]"))tab.classList.toggle("active",tab===button);render();});
function resetPage(){page=1;render();}
searchInput.addEventListener("input",resetPage);
kindFilter.addEventListener("change",resetPage);
topicFilter.addEventListener("change",resetPage);
pageSize.addEventListener("change",resetPage);
previous.addEventListener("click",()=>{page--;render();});
next.addEventListener("click",()=>{page++;render();});
document.querySelector("#studio-clear")?.addEventListener("click",()=>{status="all";kindFilter.value=topicFilter.value="all";searchInput.value="";for(const tab of document.querySelectorAll<HTMLElement>("[data-status]"))tab.classList.toggle("active",tab.dataset.status==="all");resetPage();});
function youtubeId(value:string){if(/^[\w-]{11}$/.test(value))return value;try{const url=new URL(value);if(url.hostname==="youtu.be")return url.pathname.slice(1);if(["www.youtube.com","youtube.com","m.youtube.com"].includes(url.hostname))return url.searchParams.get("v")??url.pathname.split("/").filter(Boolean).pop()??value;}catch{}return value;}
editorForm.addEventListener("submit",async(event)=>{event.preventDefault();syncRichEditors();if(input("kind").value==="article"&&!input("body").value){message(editorForm,"Write your post description first.");return;}const button=document.querySelector<HTMLButtonElement>("#save-button")!;button.disabled=true;const fields=new URLSearchParams();for(const [key,value]of new FormData(editorForm))fields.set(key,String(value));fields.set("youtube",youtubeId(fields.get("youtube")??""));if(fields.get("kind")==="video")fields.set("minutes","Video");try{await request("/admin/save",fields);dirty=false;content.hidden=false;editor.hidden=true;studioMessage.textContent=fields.get("status")==="published"?"Post saved and published.":"Draft saved. Only visible in Studio.";studioMessage.classList.add("success");await load();}catch(error){message(editorForm,(error as Error).message);}finally{button.disabled=false;}});
document.querySelector("[data-cancel-delete]")?.addEventListener("click",()=>dialog.close());
document.querySelector<HTMLButtonElement>("[data-confirm-delete]")?.addEventListener("click",async(event)=>{const button=event.currentTarget as HTMLButtonElement;button.disabled=true;try{await request(`/admin/delete/${encodeURIComponent(pendingDelete)}`,new URLSearchParams());dialog.close();await load();studioMessage.textContent="Post deleted.";studioMessage.classList.add("success");}catch(error){message(dialog,(error as Error).message);}finally{button.disabled=false;}});
window.addEventListener("beforeunload",event=>{if(dirty){event.preventDefault();event.returnValue="";}});
load();
}
