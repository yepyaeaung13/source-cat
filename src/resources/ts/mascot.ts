const cat=document.querySelector<HTMLButtonElement>('[data-relax-cat]');
const caption=document.querySelector<HTMLElement>('#cat-caption');
const messages=["Compiling… a nap.","It works on my pillow.","404: energy not found.","One more bug. Then a nap.","Have a stretch. Your code can wait.","git commit -m 'take a break'"];
let message=0;
cat?.addEventListener('click',()=>{message=(message+1)%messages.length;if(caption)caption.textContent=messages[message];cat.classList.remove('cat-stretch');requestAnimationFrame(()=>cat.classList.add('cat-stretch'));});
cat?.addEventListener('animationend',()=>cat.classList.remove('cat-stretch'));
