import "../css/app.css";
import "./icons";
import "./mascot";
import "./studio";
import "./community";
const search = document.querySelector<HTMLInputElement>("#article-search");
const cards = [...document.querySelectorAll<HTMLElement>("[data-post]")];
const filters = [...document.querySelectorAll<HTMLButtonElement>(".filter[data-category]")];
let category = "all", kind = "all";
const savedView = location.pathname === "/bookmarks";
function filterContent() {
  const query = (search?.value ?? "").trim().normalize().toLocaleLowerCase();
  let count = 0;
  for (const card of cards) {
    const match = (!savedView || card.dataset.saved === "true") && (category === "all" || card.dataset.category === category) && (kind === "all" || card.dataset.kind === kind) && (card.dataset.search ?? "").normalize().toLocaleLowerCase().includes(query);
    card.hidden = !match;
    if (match) count++;
  }
  const empty = document.querySelector<HTMLElement>("#empty-results");
  if (empty) empty.hidden = count !== 0;
  const status = document.querySelector("#search-status");
  if (status) status.textContent = `${count} ${count===1?"post":"posts"} found`;
  for (const f of filters) { const active = f.dataset.category === category; f.classList.toggle("active", active); f.setAttribute("aria-pressed",String(active)); }
  for (const f of document.querySelectorAll<HTMLElement>(".sidebar-item[data-kind]")) f.classList.toggle("selected",f.dataset.kind===kind && !(savedView && kind === "all"));
  for (const f of document.querySelectorAll<HTMLElement>(".sidebar-topic")) f.classList.toggle("selected",f.dataset.topic===category);
}
search?.addEventListener("input",filterContent);
for (const f of filters) f.addEventListener("click",()=>{category=f.dataset.category??"all";filterContent();});
for (const f of document.querySelectorAll<HTMLElement>(".sidebar-item[data-kind]")) f.addEventListener("click",()=>{if(savedView&&f.dataset.kind==="all"){location.href="/";return;}kind=f.dataset.kind??"all";category="all";filterContent();});
for (const f of document.querySelectorAll<HTMLElement>(".sidebar-topic")) f.addEventListener("click",()=>{category=f.dataset.topic??"all";kind="all";filterContent();});
document.querySelector("[data-reset]")?.addEventListener("click",()=>{category=kind="all";if(search) search.value="";filterContent();});
document.querySelector("[data-menu]")?.addEventListener("click",()=>{const mobile=window.matchMedia("(max-width:760px)").matches;document.body.classList.toggle(mobile?"mobile-sidebar-open":"sidebar-hidden");document.querySelector("[data-menu]")?.setAttribute("aria-expanded",String(mobile?document.body.classList.contains("mobile-sidebar-open"):!document.body.classList.contains("sidebar-hidden")));});
for (const button of document.querySelectorAll<HTMLButtonElement>("[data-play]")) button.addEventListener("click",()=>{const id=button.dataset.play;const cover=button.closest<HTMLElement>("[data-video]");if(!id||!/^[\w-]{11}$/.test(id)||!cover)return;const frame=document.createElement("iframe");frame.src=`https://www.youtube-nocookie.com/embed/${id}?autoplay=1`;frame.title=button.getAttribute("aria-label")??"YouTube video";frame.allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture; web-share";frame.allowFullscreen=true;frame.referrerPolicy="strict-origin-when-cross-origin";cover.replaceChildren(frame);frame.focus();});
async function copy(url:string){try{await navigator.clipboard.writeText(url);const toast=document.createElement("div");toast.className="toast";toast.setAttribute("role","status");toast.textContent="Link copied ✓";document.body.append(toast);setTimeout(()=>toast.remove(),2200);}catch{window.prompt("Copy this post link",url);}}
document.querySelector("[data-share]")?.addEventListener("click",()=>copy(location.href));
for(const button of document.querySelectorAll<HTMLElement>("[data-copy]"))button.addEventListener("click",()=>copy(new URL(button.dataset.copy??"/",location.origin).href));

window.addEventListener("bookmarks:changed", filterContent);
if(savedView)document.querySelector(".bookmarks-nav")?.classList.add("selected");
if(search) filterContent();
