// Native editing keeps formatting and undo available without a remote dependency.
const allowed = new Set(["P","DIV","BR","H2","H3","STRONG","B","EM","I","U","S","UL","OL","LI","BLOCKQUOTE","PRE","CODE","A"]);
export function cleanRichText(html:string):string {
  const source=document.createElement("template");source.innerHTML=html;
  function clean(node:Node):Node {
    if(node.nodeType===Node.TEXT_NODE)return document.createTextNode(node.textContent??"");
    const fragment=document.createDocumentFragment();
    if(!(node instanceof HTMLElement))return fragment;
    if(["SCRIPT","STYLE","IFRAME","OBJECT","SVG","FORM","INPUT","BUTTON"].includes(node.tagName))return fragment;
    const children=[...node.childNodes].map(clean);
    if(!allowed.has(node.tagName)){fragment.append(...children);return fragment;}
    const output=document.createElement(node.tagName==="DIV"?"p":node.tagName.toLowerCase());
    if(node.tagName==="A"){
      const href=node.getAttribute("href")??"";
      if(/^(https?:\/\/|mailto:)/i.test(href)){output.setAttribute("href",href);output.setAttribute("rel","noopener noreferrer");}
    }
    output.append(...children);return output;
  }
  const result=document.createElement("div");result.append(...[...source.content.childNodes].map(clean));return result.innerHTML;
}
const editors=[...document.querySelectorAll<HTMLElement>("[data-rich-editor]")];
for(const wrapper of editors){
  const surface=wrapper.querySelector<HTMLElement>("[contenteditable]")!;
  const hidden=wrapper.querySelector<HTMLTextAreaElement>("textarea")!;
  const sync=()=>{hidden.value=cleanRichText(surface.innerHTML);hidden.dispatchEvent(new Event("input",{bubbles:true}));};
  const toolbar=wrapper.querySelector<HTMLElement>(".rich-toolbar")!;
  toolbar.addEventListener("mousedown",event=>{if((event.target as Element).closest("button"))event.preventDefault();});
  toolbar.addEventListener("click",event=>{
    const button=(event.target as Element).closest<HTMLButtonElement>("button");if(!button)return;
    surface.focus();const command=button.dataset.command;
    if(command==="link"){
      const href=window.prompt("Link URL (https://…)");if(!href)return;
      if(!/^https?:\/\//i.test(href)){window.alert("Use an http:// or https:// URL.");return;}
      if(!window.getSelection()?.toString())document.execCommand("insertText",false,href);
      document.execCommand("createLink",false,href);
    }else if(command==="code"){
      const selected=window.getSelection()?.toString()||"Your code here";const pre=document.createElement("pre");const code=document.createElement("code");code.textContent=selected;pre.append(code);document.execCommand("insertHTML",false,pre.outerHTML+"<p><br></p>");
    }else if(command==="formatBlock")document.execCommand(command,false,button.dataset.value??"p");
    else if(command)document.execCommand(command,false);
    sync();
  });
  surface.addEventListener("input",sync);
  surface.addEventListener("paste",event=>{
    event.preventDefault();const html=event.clipboardData?.getData("text/html");
    if(html)document.execCommand("insertHTML",false,cleanRichText(html));
    else document.execCommand("insertText",false,event.clipboardData?.getData("text/plain")??"");
    sync();
  });
  surface.addEventListener("drop",event=>event.preventDefault());
  wrapper.addEventListener("richtext:load",()=>{surface.innerHTML=cleanRichText(hidden.value);});
}
export function loadRichEditors(){for(const editor of editors)editor.dispatchEvent(new Event("richtext:load"));}
export function syncRichEditors(){for(const editor of editors){const surface=editor.querySelector<HTMLElement>("[contenteditable]")!;editor.querySelector<HTMLTextAreaElement>("textarea")!.value=surface.textContent?.trim()?cleanRichText(surface.innerHTML):"";}}
