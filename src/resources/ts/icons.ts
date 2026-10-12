import { createIcons, Menu, Search, LayoutDashboard, House, FileText, Video, Bookmark, MessagesSquare, ExternalLink, ArrowLeft, ArrowRight, Play, Sparkles, EllipsisVertical, X, Hash, Plus, RefreshCw, Undo2, Redo2, Quote, Pilcrow, Bold, Italic, Heading2, Heading3, List, ListOrdered, Code, Unlink, CircleHelp } from "lucide";
const icons={Menu,Search,LayoutDashboard,House,FileText,Video,Bookmark,MessagesSquare,ExternalLink,ArrowLeft,ArrowRight,Play,Sparkles,EllipsisVertical,X,Hash,Plus,RefreshCw,Undo2,Redo2,Quote,Pilcrow,Bold,Italic,Heading2,Heading3,List,ListOrdered,Code,Unlink,CircleHelp};
function renderIcons(){if(document.querySelector('i[data-lucide]'))createIcons({icons,attrs:{class:"ui-icon","aria-hidden":"true",focusable:"false"}});}
renderIcons();
// Render only new placeholders; SVG replacements do not schedule another pass.
new MutationObserver(records=>{if(records.some(record=>[...record.addedNodes].some(node=>node instanceof Element&&(node.matches('i[data-lucide]')||node.querySelector('i[data-lucide]')))))renderIcons();}).observe(document.body,{childList:true,subtree:true});
