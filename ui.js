/* SafeStart · ชุดเครื่องมือหน้าจอ (ui.js) */
const {useState,useEffect,useRef,useMemo,useCallback,Fragment}=React;
const html=htm.bind(React.createElement);
const z=n=>String(n).padStart(2,'0');
const ymd=d=>d.getFullYear()+'-'+z(d.getMonth()+1)+'-'+z(d.getDate());
const today=()=>ymd(new Date());
const addDays=(s,n)=>{const d=new Date(s+'T00:00:00');d.setDate(d.getDate()+n);return ymd(d)};
const thD=s=>s?new Date(s+'T00:00:00').toLocaleDateString('th-TH',{day:'numeric',month:'short',year:'2-digit'}):'–';
const thDS=s=>s?new Date(s+'T00:00:00').toLocaleDateString('th-TH',{day:'numeric',month:'short'}):'–';
const thDL=s=>new Date(s+'T00:00:00').toLocaleDateString('th-TH',{weekday:'long',day:'numeric',month:'long'});
const thT=t=>t?new Date(t).toLocaleString('th-TH',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}):'–';
const hm=t=>t?new Date(t).toLocaleTimeString('th-TH',{hour:'2-digit',minute:'2-digit'}):'–';
const ago=t=>{const m=Math.round((Date.now()-new Date(t))/6e4);if(m<1)return'เมื่อสักครู่';if(m<60)return m+' นาทีที่แล้ว';const h=Math.round(m/60);if(h<24)return h+' ชม.ที่แล้ว';return Math.round(h/24)+' วันที่แล้ว'};
const initials=n=>{const x=(n||'?').replace(/^(นาย|นางสาว|นาง|Mr\.|Mrs\.|Ms\.)\s*/,'').trim();return x.length<=3?x:(/^[a-z]/i.test(x)?x.slice(0,2):x.split(' ')[0].slice(0,3))||'?'};
const lsGet=k=>{try{return JSON.parse(localStorage.getItem(k)||'null')}catch(e){return null}};
const lsSet=(k,v)=>{try{v==null?localStorage.removeItem(k):localStorage.setItem(k,JSON.stringify(v))}catch(e){}};
const cx=(...a)=>a.filter(Boolean).join(' ');
const uid=()=>Math.random().toString(36).slice(2,10)+Date.now().toString(36);
const UI={toast:m=>alert(m),open:()=>{},close:()=>{},replace:()=>{},zoom:()=>{},go:()=>{},pickCo:()=>{}};
const errMsg=e=>{const m=(e&&(e.message||e.error_description||e.msg))||String(e);return m.replace(/^.*?ERROR:\s*/,'')};
async function run(fn,ok){try{const r=await fn();if(ok)UI.toast(ok);return r==null?true:r}catch(e){console.error(e);UI.toast(errMsg(e));return false}}
function loadScript(src,glob){return new Promise((res,rej)=>{if(window[glob])return res(window[glob]);const s=document.createElement('script');s.src=src;s.onload=()=>res(window[glob]);s.onerror=()=>rej(new Error('โหลดไลบรารีไม่สำเร็จ'));document.head.appendChild(s)})}

/* ---------- ไอคอนเส้น (ชุดเดียวทั้งระบบ) ---------- */
const P={
  home:'<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-5h4v5"/>',
  cal:'<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  check:'<path d="M9 12.5l2 2 4-4.5"/><path d="M12 3l7.5 3v6c0 4.5-3.2 7.7-7.5 9-4.3-1.3-7.5-4.5-7.5-9V6z"/>',
  team:'<circle cx="9" cy="8" r="3.2"/><path d="M3 20c.6-3.4 3-5 6-5s5.4 1.6 6 5"/><circle cx="17" cy="9" r="2.4"/><path d="M16.5 14c2.3.2 3.9 1.7 4.5 4.5"/>',
  more:'<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>',
  building:'<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 7h1M14 7h1M9 11h1M14 11h1M9 15h1M14 15h1M10 21v-3h4v3"/>',
  flag:'<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>',
  warn:'<path d="M12 3.5l9.5 16.5h-19z"/><path d="M12 10v4.5M12 17.5v.5"/>',
  map:'<path d="M12 21s-6.5-5.6-6.5-11A6.5 6.5 0 0 1 18.5 10c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
  inbox:'<path d="M4 13l2.5-8h11L20 13v6H4z"/><path d="M4 13h4.5l1 2.5h5l1-2.5H20"/>',
  report:'<path d="M6 3h9l4 4v14H6z"/><path d="M9 12h6M9 16h6M9 8h3"/>',
  cog:'<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>',
  bell:'<path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
  phone:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
  x:'<path d="M6 6l12 12M18 6L6 18"/>', plus:'<path d="M12 5v14M5 12h14"/>', chev:'<path d="M9 6l6 6-6 6"/>', back:'<path d="M15 6l-6 6 6 6"/>',
  camera:'<path d="M4 8h3l2-2.5h6L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  qr:'<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM18 14h2M14 18v2"/>',
  scan:'<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><path d="M4 12h16"/>',
  history:'<path d="M3.5 12a8.5 8.5 0 1 0 2.5-6"/><path d="M3 4v4h4"/><path d="M12 8v4l3 2"/>',
  clock:'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  download:'<path d="M12 4v11M7 10l5 5 5-5"/><path d="M5 20h14"/>', upload:'<path d="M12 20V9M7 14l5-5 5 5"/><path d="M5 4h14"/>',
  mega:'<path d="M4 10v4h3l7 4V6L7 10z"/><path d="M17.5 9a4 4 0 0 1 0 6"/>',
  ok:'<path d="M5 12.5l4.5 4.5L19 7.5"/>', alert:'<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5M12 16v.5"/>', info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8v.5"/>',
  user:'<circle cx="12" cy="8" r="3.5"/><path d="M5 20c.8-4 3.5-6 7-6s6.2 2 7 6"/>', edit:'<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
  shield:'<path d="M12 3l7.5 3v6c0 4.5-3.2 7.7-7.5 9-4.3-1.3-7.5-4.5-7.5-9V6z"/>',
  sos:'<circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16.5v.5"/>',
  heart:'<path d="M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 7.5 2.8C19.5 15.4 12 20 12 20z"/><path d="M5 12h4l1.5-2.5 2 5L14 12h5"/>',
  cloud:'<path d="M7 18a4.5 4.5 0 1 1 1-8.9A6 6 0 0 1 19.5 11 3.5 3.5 0 0 1 18 18z"/>',
  storm:'<path d="M7 16a4.5 4.5 0 1 1 1-8.9A6 6 0 0 1 19.5 9 3.5 3.5 0 0 1 18 16"/><path d="M13 12l-3 5h4l-3 5"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8"/>',
  wind:'<path d="M3 9h11a3 3 0 1 0-3-3M3 15h15a3 3 0 1 1-3 3M3 12h7"/>',
  speaker:'<path d="M4 9.5v5h3.5L12 18V6L7.5 9.5z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
  doc:'<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/>', id:'<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2.2"/><path d="M5.5 16c.5-1.7 1.8-2.6 3.5-2.6s3 .9 3.5 2.6M14.5 10h4M14.5 13.5h3"/>',
  logout:'<path d="M14 4h5v16h-5M10 8l-4 4 4 4M6 12h10"/>', swap:'<path d="M7 7h12l-3-3M17 17H5l3 3"/>', search:'<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/>',
  book:'<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5z"/><path d="M4 20.5A2.5 2.5 0 0 1 6.5 18H20v3H6.5"/>',
  lock:'<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
  // กลุ่มอันตราย
  wah:'<path d="M3 12l9-7 9 7"/><path d="M6 21l3.5-9M9 15h3.5M8 18h3.5"/><circle cx="16.5" cy="9.5" r="1.4"/><path d="M16 11.5l-1 4 2.5 3M15.5 13l2.5.8"/>',
  electric:'<path d="M13 2.5L5 13.5h6l-1 8 8-11h-6z"/>',
  hot:'<path d="M12 21c-3.9 0-6.5-2.6-6.5-6 0-4.3 4.2-6.2 4.7-10.5 3.1 2 4.2 4.6 3.7 7.1 1.1-.6 1.9-1.8 2.1-3.2 1.6 1.7 2.5 3.8 2.5 6.6 0 3.4-2.6 6-6.5 6z"/>',
  confined:'<path d="M3 10l9-6.5L21 10"/><path d="M5 9v11h14V9"/><path d="M8 13h8v4H8z"/>',
  lifting:'<path d="M5 21V4h13M18 4v5"/><path d="M15.5 9h5v4h-5zM5 8l5-4"/>',
  excavation:'<path d="M14 3l7 7M17.5 6.5L8 16"/><path d="M8 16l-4.5 1.5L5 13l3 3z"/><path d="M3 21h18"/>',
  chemical:'<path d="M9 3h6M10 3v6L4.8 18.2A2 2 0 0 0 6.5 21h11a2 2 0 0 0 1.7-2.8L14 9V3"/><path d="M7.5 15h9"/>',
};
const Ic=({n,s})=>html`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style=${s?{width:s,height:s}:null} dangerouslySetInnerHTML=${{__html:P[n]||''}}></svg>`;
const HZ_ORDER=['wah','electric','hot','confined','lifting','excavation','chemical'];

/* ---------- ภาพลายเส้นประกอบเช็กลิสต์ (viewBox 64) ---------- */
const g=(s)=>s;
const ILL={
  fit:g('<circle cx="32" cy="14" r="7"/><path d="M20 58V36a12 12 0 0 1 24 0v22"/><path d="M50 18l4 4 8-9" class="ok"/>'),
  ppe:g('<path d="M16 26a16 16 0 0 1 32 0z"/><path d="M12 26h40"/><path d="M20 26c0 9 5 14 12 14s12-5 12-14" /><path d="M22 38c-2 6 0 10 0 10" class="ac"/><path d="M14 54h14l2-6h-14zM36 54h14l2-6H38z"/>'),
  toolbox:g('<circle cx="16" cy="22" r="6"/><circle cx="32" cy="18" r="6"/><circle cx="48" cy="22" r="6"/><path d="M6 46c1-8 5-12 10-12s9 4 10 12M22 42c1-8 5-12 10-12s9 4 10 12M38 46c1-8 5-12 10-12s9 4 10 12"/><path d="M8 54h48" class="ac"/>'),
  tool:g('<path d="M8 40h30l6-8h8v16h-8l-6-4H8z"/><path d="M14 40v12h8V40"/><path d="M52 32v-6" class="ac"/>'),
  rcd:g('<rect x="10" y="12" width="26" height="40" rx="3"/><rect x="16" y="20" width="14" height="10" rx="1" class="ac"/><circle cx="23" cy="42" r="3"/><path d="M36 32h10c6 0 8 6 8 10v10"/>'),
  barricade:g('<path d="M6 30h52M6 42h52" /><path d="M10 30l8 12M22 30l8 12M34 30l8 12M46 30l8 12" class="ac"/><path d="M12 42v14M52 42v14"/>'),
  firstaid:g('<rect x="8" y="18" width="30" height="26" rx="3"/><path d="M23 24v14M16 31h14" class="ac"/><path d="M46 56V30a5 5 0 0 1 10 0v26zM48 30v-8h6v8"/>'),
  truck:g('<path d="M4 40V22h32v18M36 28h12l8 8v4H36"/><circle cx="14" cy="44" r="5"/><circle cx="46" cy="44" r="5"/><path d="M52 50l6 0M50 46l6 4" class="ac"/>'),
  phone:g('<rect x="20" y="6" width="24" height="52" rx="4"/><path d="M28 50h8"/><path d="M26 22h12M26 30h8" class="ac"/>'),
  weather:g('<path d="M18 40a10 10 0 1 1 3-19.5A13 13 0 0 1 46 24a8 8 0 0 1-2 16z"/><path d="M30 34l-5 9h8l-5 10" class="ac"/>'),
  anchor:g('<path d="M4 38L32 14l28 24"/><path d="M32 14v-6" /><circle cx="32" cy="8" r="3" class="ac"/><path d="M32 11c-6 8-12 18-14 30" stroke-dasharray="3 3" class="ac"/><path d="M8 52h48"/>'),
  system:g('<path d="M4 44l20-18h36"/><path d="M14 36l-6 10M48 26v26" class="ac"/><text x="20" y="58" font-size="9">&lt;20°  &gt;20°</text>'),
  harness:g('<circle cx="32" cy="10" r="6"/><path d="M22 20h20l-2 18H24z"/><path d="M24 20l16 18M40 20L24 38M24 38l-4 20M40 38l4 20"/><path d="M32 20c0-8 10-12 14-6l6 12" class="ac"/><circle cx="52" cy="28" r="3" class="ac"/>'),
  walkway:g('<path d="M4 44L32 20l28 24"/><path d="M14 40h36l-4 6H18z" class="ac"/><path d="M20 40v6M26 40v6M32 40v6M38 40v6M44 40v6"/>'),
  buddy:g('<circle cx="20" cy="16" r="6"/><circle cx="44" cy="16" r="6"/><path d="M10 44c1-10 5-16 10-16s9 6 10 16M34 44c1-10 5-16 10-16s9 6 10 16"/><path d="M28 34h8" class="ac"/><path d="M6 54h52"/>'),
  edge:g('<path d="M4 40h40v18"/><path d="M8 40V26h36v14" /><path d="M8 32h36" class="ac"/><path d="M50 30l8 8M58 30l-8 8"/>'),
  toollanyard:g('<path d="M14 10c0 18 6 26 20 30" class="ac" stroke-dasharray="3 3"/><path d="M30 38l14 4-2 8-14-4zM42 42l8-8 6 6-8 8"/><circle cx="14" cy="10" r="3"/>'),
  below:g('<path d="M10 14h44"/><path d="M28 20l4 10 4-10" class="ac"/><path d="M8 44h48M14 44v12M50 44v12"/><path d="M14 50h36" class="ac"/>'),
  powerline:g('<path d="M10 6v52M54 6v52M6 14h52"/><path d="M10 18c14 8 30 8 44 0" class="ac"/><path d="M20 40h24M32 34v12"/><text x="22" y="58" font-size="9">≥ 3 ม.</text>'),
  rain:g('<path d="M16 32a10 10 0 1 1 3-19.5A13 13 0 0 1 44 16a8 8 0 0 1-2 16z"/><path d="M20 40l-3 8M30 40l-3 8M40 40l-3 8" class="ac"/>'),
  ladder:g('<path d="M18 58L32 6M30 58L44 6"/><path d="M21 48h12M24 38h12M27 28h12M30 18h12" class="ac"/>'),
  ladder_fiber:g('<path d="M18 58L32 6M30 58L44 6" class="ac"/><path d="M21 48h12M24 38h12M27 28h12M30 18h12"/><path d="M50 10l-4 8h5l-4 8"/>'),
  ladder_angle:g('<path d="M44 6v52M4 58h56"/><path d="M14 58L40 12" /><path d="M20 58L46 12"/><path d="M40 12l4-6" class="ac" stroke-dasharray="2 2"/><path d="M8 58a10 10 0 0 1 4-8" class="ac"/><text x="2" y="48" font-size="8">75°</text>'),
  ladder_a:g('<path d="M32 6L14 58M32 6l18 52"/><path d="M19 44h26M23 32h18" class="ac"/><path d="M26 22h12" stroke-dasharray="2 2"/>'),
  scaffold_tag:g('<path d="M10 6v52M40 6v52M10 20h30M10 40h30"/><rect x="44" y="18" width="16" height="22" rx="2" class="ac"/><path d="M48 28l3 3 6-6" class="ac"/><path d="M40 22h4"/>'),
  scaffold:g('<path d="M10 6v52M54 6v52M10 22h44M10 42h44M10 22l44 20"/><path d="M6 58h52"/><path d="M14 18h36" class="ac"/>'),
  guardrail:g('<path d="M8 50h48M12 50V18M52 50V18M12 18h40M12 34h40" class="ac"/><path d="M8 50v4h48v-4"/>'),
  baseplate:g('<path d="M24 6v42M40 6v42"/><path d="M14 48h36v6H14z" class="ac"/><path d="M8 58h48"/>'),
  engineer:g('<circle cx="24" cy="18" r="7"/><path d="M14 18a10 10 0 0 1 20 0z" class="ac"/><path d="M12 50c1-10 5-16 12-16s11 6 12 16"/><rect x="38" y="28" width="20" height="26" rx="2"/><path d="M42 36h12M42 42h8"/>'),
  loto:g('<rect x="10" y="10" width="30" height="40" rx="3"/><path d="M18 20h14M18 28h14"/><rect x="36" y="34" width="16" height="14" rx="2" class="ac"/><path d="M40 34v-5a4 4 0 0 1 8 0v5" class="ac"/><path d="M44 48v10"/>'),
  fan:g('<circle cx="32" cy="32" r="22"/><circle cx="32" cy="32" r="3"/><path d="M32 29c-2-8 2-14 8-12M35 33c8 1 11 7 6 11M29 34c-5 6-12 5-12-1" class="ac"/>'),
  watch:g('<circle cx="18" cy="16" r="6"/><path d="M8 44c1-10 5-16 10-16s9 6 10 16"/><path d="M34 26h22v20H34z"/><path d="M28 30l4 2" class="ac"/><path d="M38 34h14" class="ac"/>'),
  mask:g('<path d="M12 30c8-6 32-6 40 0l-4 16c-10 6-22 6-32 0z"/><path d="M12 30L4 26M52 30l8-4" /><path d="M24 36h16M24 42h16" class="ac"/>'),
  water:g('<path d="M22 8h20l-2 48H24z"/><path d="M22 22h20" class="ac"/><path d="M50 30c4 6 6 9 6 12a6 6 0 0 1-12 0c0-3 2-6 6-12z" class="ac"/>'),
  ceiling_walk:g('<path d="M4 16h56"/><path d="M8 16v20M24 16v20M40 16v20M56 16v20"/><path d="M6 30h52v6H6z" class="ac"/><circle cx="32" cy="46" r="0"/><path d="M4 52h56" stroke-dasharray="4 4"/>'),
  owner:g('<path d="M4 30L22 14l18 16"/><path d="M8 28v26h28V28"/><circle cx="50" cy="26" r="5"/><path d="M42 50c1-8 4-12 8-12s7 4 8 12"/><path d="M40 20h8" class="ac"/>'),
  kids:g('<circle cx="18" cy="26" r="5"/><path d="M10 50c1-8 4-14 8-14s7 6 8 14"/><path d="M34 18h24v34" class="ac"/><path d="M34 18v34" class="ac"/><path d="M40 30l12 12M52 30L40 42"/>'),
  cover:g('<path d="M6 40l6-14h40l6 14v10H6z"/><circle cx="16" cy="50" r="4"/><circle cx="48" cy="50" r="4"/><path d="M4 22c10-8 46-8 56 0v18" class="ac"/>'),
  path:g('<path d="M22 58l6-52M42 58l-6-52" /><path d="M30 46h4M31 34h3M32 22h2" class="ac"/><path d="M6 30c8 4 10 10 6 18" />'),
  meter:g('<rect x="14" y="8" width="24" height="40" rx="4"/><rect x="18" y="14" width="16" height="10" rx="1" class="ac"/><path d="M22 48l-6 12M30 48l8 10"/><path d="M46 20l-4 8h5l-4 8" class="ac"/>'),
  cert:g('<rect x="10" y="8" width="36" height="46" rx="3"/><path d="M18 20h20M18 28h14"/><circle cx="40" cy="44" r="8" class="ac"/><path d="M36 52l-2 8 6-3 6 3-2-8" class="ac"/>'),
  insulated:g('<path d="M10 54l20-20" /><path d="M30 34l6-6 4 4-6 6z" class="ac"/><path d="M40 28l12-12M48 12l8 8"/><path d="M14 12c6 0 10 4 10 10" />'),
  solar:g('<path d="M6 46l10-28h42l-10 28z"/><path d="M26 18l-6 28M40 18l-6 28M11 32h43"/><path d="M50 6l-3 6h4l-3 6" class="ac"/>'),
  extinguisher:g('<path d="M22 20h16v36H22z"/><path d="M26 20v-6h8v6M34 12l12-4" /><path d="M22 30h16" class="ac"/><path d="M46 8c4 8 4 16 0 22" class="ac"/>'),
  combustible:g('<path d="M8 50h20V30H8z"/><path d="M12 30v-6h12v6"/><path d="M44 54c-5 0-8-3-8-7 0-6 6-8 6-14 4 3 6 6 5 10 2-1 3-3 3-5 2 2 3 5 3 8 0 5-4 8-9 8z" class="ac"/><path d="M30 20l26 32" />'),
  welder:g('<rect x="6" y="30" width="22" height="20" rx="2"/><path d="M28 36c10 0 12 8 18 10"/><path d="M46 46l6 4" /><path d="M54 40l4-4M56 48h6M52 54l4 4" class="ac"/>'),
  gas:g('<rect x="22" y="14" width="18" height="44" rx="8"/><path d="M28 14V8h6v6M34 8h8"/><path d="M18 30h26" class="ac"/>'),
  shield:g('<path d="M14 10h36v26c0 10-8 18-18 20-10-2-18-10-18-20z"/><rect x="20" y="20" width="24" height="10" rx="2" class="ac"/>'),
  sling:g('<path d="M32 4v12"/><path d="M26 16h12l-6 8z"/><path d="M32 24L14 44M32 24l18 20" class="ac"/><rect x="10" y="44" width="44" height="12" rx="2"/>'),
  lift2:g('<circle cx="12" cy="14" r="5"/><circle cx="52" cy="14" r="5"/><path d="M4 50c1-10 4-16 8-16M60 50c-1-10-4-16-8-16"/><path d="M8 32h48v6H8z" class="ac"/><path d="M56 38c4 4 4 12 0 18" stroke-dasharray="3 3"/>'),
  catcher:g('<path d="M4 34L30 12l30 22"/><circle cx="44" cy="10" r="4"/><path d="M44 14v12M38 18l12 2" /><path d="M28 50V30h6v20" class="ac"/><path d="M30 30l14-8"/>'),
  pipe:g('<path d="M4 20h56"/><path d="M6 36h52" class="ac"/><path d="M6 44h52"/><path d="M28 6v20M22 20l6 6 6-6"/>'),
  trench:g('<path d="M4 20h16l6 36h12l6-36h16"/><path d="M26 30h12M28 42h8" class="ac"/>'),
  sds:g('<rect x="10" y="8" width="34" height="48" rx="3"/><path d="M16 18h22M16 26h22M16 34h14"/><path d="M40 38l12 0 6 10-6 10H40l-6-10z" class="ac"/>'),
  wind:g('<path d="M4 22h34a7 7 0 1 0-7-7M4 38h44a7 7 0 1 1-7 7M4 30h20" class="ac"/>'),
};
const Ill=({k,s})=>html`<svg className="ill" viewBox="0 0 64 64" width=${s||64} height=${s||64} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" dangerouslySetInnerHTML=${{__html:ILL[k]||ILL.fit}}></svg>`;
/* ภาพพื้นหลังลายเส้นจาง (บ้าน / หลังคา / เมือง) */
const BGART={
  house:'<path d="M20 170 150 70 280 170M50 150v120h200V150M120 270v-60h60v60M70 175h40v35H70zM190 175h40v35h-40z"/><path d="M215 105v-40h25v60"/>',
  roof:'<path d="M10 200 150 90 290 200"/><path d="M40 176 150 90M70 200 150 120M230 200 150 120"/><path d="M200 60v40M190 50l20 20M210 50l-20 20"/><path d="M60 230h180M60 260h180"/>',
  city:'<path d="M10 260h280M30 260V150h50v110M90 260V110h60v150M160 260V170h40v90M210 260V130h60v130"/><path d="M45 170h20M45 200h20M105 130h30M105 160h30M225 150h30M225 180h30"/>',
};
const BgArt=({k})=>html`<svg className="bgart" viewBox="0 0 300 300" fill="none" stroke="currentColor" strokeWidth="3" aria-hidden="true" dangerouslySetInnerHTML=${{__html:BGART[k]||BGART.house}}></svg>`;

const Chip=({t,c,dot,icon})=>html`<span className=${cx('chip',c)}>${dot?html`<span className="d"></span>`:null}${icon?html`<${Ic} n=${icon} s=${14}/>`:null}${t}</span>`;
function Btn({children,kind,small,big,block,icon,onClick,disabled,type,title}){const [busy,setBusy]=useState(false);
  const click=async e=>{if(!onClick||busy)return;const r=onClick(e);if(r&&r.then){setBusy(true);try{await r}finally{setBusy(false)}}};
  return html`<button type=${type||'button'} title=${title} className=${cx('btn',kind,small&&'small',big&&'big',block&&'block')} onClick=${click} disabled=${disabled||busy}>${icon?html`<${Ic} n=${icon}/>`:null}${busy?'กำลังบันทึก…':children}</button>`}
const Card=({children,pad,style,className})=>html`<div className=${cx('card',pad&&'pad',className)} style=${style}>${children}</div>`;
const CardH=({title,sub,right,icon})=>html`<div className="card-h"><div className="row" style=${{gap:10}}>${icon?html`<span className="ic-circle mute"><${Ic} n=${icon}/></span>`:null}<div><h3>${title}</h3>${sub?html`<div className="sm muted">${sub}</div>`:null}</div></div>${right||null}</div>`;
const Empty=({icon,t,sub,action})=>html`<div className="empty"><${Ic} n=${icon||'info'}/><div style=${{fontWeight:600,color:'var(--ink-2)'}}>${t}</div>${sub?html`<div className="sm">${sub}</div>`:null}${action||null}</div>`;
const Field=({label,hint,children,span})=>html`<div className=${cx('field',span&&'span-all')}><label>${label}</label>${children}${hint?html`<div className="hint">${hint}</div>`:null}</div>`;
const Inp=({v,set,type,ph,mode,max,id,min})=>html`<input id=${id} className="inp" type=${type||'text'} value=${v??''} placeholder=${ph} inputMode=${mode} maxLength=${max} min=${min} onChange=${e=>set(e.target.value)}/>`;
const Txt=({v,set,ph,rows})=>html`<textarea className="inp" rows=${rows} value=${v??''} placeholder=${ph} onChange=${e=>set(e.target.value)}></textarea>`;
const Sel=({v,set,opts,label})=>html`<select className="inp" aria-label=${label} value=${v??''} onChange=${e=>set(e.target.value)}>${opts.map(o=>Array.isArray(o)?html`<option key=${o[0]} value=${o[0]}>${o[1]}</option>`:html`<option key=${o} value=${o}>${o}</option>`)}</select>`;
const Seg=({v,set,opts})=>html`<div className="seg" role="tablist">${opts.map(([k,l])=>html`<button key=${k} role="tab" aria-selected=${v===k} className=${v===k?'on':''} onClick=${()=>set(k)}>${l}</button>`)}</div>`;
const Tabs=({v,set,opts})=>html`<div className="tabs" role="tablist">${opts.map(([k,l,n,ic])=>html`<button key=${k} role="tab" aria-selected=${v===k} className=${v===k?'on':''} onClick=${()=>set(k)}>${ic?html`<${Ic} n=${ic} s=${17}/>`:null}${l}${n?html`<span className="n">${n}</span>`:null}</button>`)}</div>`;
const Banner=({kind,icon,children})=>html`<div className=${'banner '+kind}><${Ic} n=${icon||(kind==='go'?'ok':kind==='info'?'info':'alert')}/><div className="grow">${children}</div></div>`;
const Stepper=({n,i})=>html`<div className="stepper">${Array.from({length:n},(_,k)=>html`<i key=${k} className=${k<i?'done':k===i?'on':''}></i>`)}</div>`;
const Avatar=({n,lg,dot})=>html`<div className=${cx('avatar',lg&&'lg')}>${initials(n)}${dot?html`<i className=${'adot '+dot}></i>`:null}</div>`;
const Check=({on,set,children,disabled})=>html`<label className=${cx('checkrow',on&&'on',disabled&&'dis')}><input type="checkbox" checked=${!!on} disabled=${disabled} onChange=${e=>set(e.target.checked)}/><span className="box"><${Ic} n="ok" s=${16}/></span><span className="grow">${children}</span></label>`;

/* ปุ่มตอบเช็กลิสต์ 3 ปุ่มใหญ่ */
function PFN({v,set,na}){return html`<div className=${cx('pfn',na&&'three')}>
  <button className=${cx('p',v==='pass'&&'on')} aria-pressed=${v==='pass'} onClick=${()=>set('pass')}><${Ic} n="ok"/>ผ่าน</button>
  <button className=${cx('f',v==='fail'&&'on')} aria-pressed=${v==='fail'} onClick=${()=>set('fail')}><${Ic} n="x"/>ไม่ผ่าน</button>
  ${na?html`<button className=${cx('n',v==='na'&&'on')} aria-pressed=${v==='na'} onClick=${()=>set('na')}>— ไม่ใช้</button>`:null}</div>`}

/* หน้าซ้อน: ← ย้อนกลับ + ปุ่มย้อนของมือถือปิดทีละชั้น */
function Sheet({title,sub,children,foot,size,onClose,head}){
  const close=onClose||UI.close;
  useEffect(()=>{const k=e=>{if(e.key==='Escape')close()};document.addEventListener('keydown',k);return()=>document.removeEventListener('keydown',k)},[]);
  return html`<div className="sheet-bg" onMouseDown=${e=>{if(e.target===e.currentTarget)close()}}><div className=${cx('sheet',size)} role="dialog" aria-modal="true" aria-label=${title}>
  <div className="sheet-h"><button className="x" aria-label="ย้อนกลับ" onClick=${close}><${Ic} n="back"/></button><div className="grow" style=${{minWidth:0}}><h2>${title}</h2>${sub?html`<div className="sm muted ell">${sub}</div>`:null}</div>${head||null}</div>
  <div className="sheet-b">${children}</div>${foot?html`<div className="sheet-f">${foot}</div>`:null}</div></div>`}

/* ปุ่มกดค้าง (SOS) */
function HoldButton({ms,onHold,className,children,label}){const [p,setP]=useState(0);const t=useRef(null);
  const start=e=>{e.preventDefault();const t0=Date.now();clearInterval(t.current);t.current=setInterval(()=>{const x=Math.min(1,(Date.now()-t0)/(ms||1000));setP(x);if(x>=1){clearInterval(t.current);setP(0);try{navigator.vibrate&&navigator.vibrate(200)}catch(_){}onHold()}},30)};
  const stop=()=>{clearInterval(t.current);setP(0)};
  return html`<button className=${className} aria-label=${label} onPointerDown=${start} onPointerUp=${stop} onPointerLeave=${stop} onPointerCancel=${stop} onKeyDown=${e=>{if(e.key==='Enter')onHold()}} style=${{'--p':p}}>${children}</button>`}

/* ---------- รูปภาพ: ย่อ + ประทับเวลา แล้วอัปโหลด ---------- */
function loadImg(src){return new Promise((res,rej)=>{const im=new Image();im.onload=()=>res(im);im.onerror=()=>rej(new Error('เปิดรูปไม่ได้'));im.src=src})}
/* อ่านเวลาถ่ายและพิกัดจาก EXIF ของรูป JPEG (ถ้ามี) */
async function readExif(file){try{if(!/jpe?g/i.test(file.type))return{};const b=new DataView(await file.slice(0,262144).arrayBuffer());if(b.getUint16(0)!==0xFFD8)return{};
  let o=2;while(o<b.byteLength-4){const m=b.getUint16(o),len=b.getUint16(o+2);if(m===0xFFE1&&b.getUint32(o+4)===0x45786966){const t=o+10,le=b.getUint16(t)===0x4949;
    const u16=x=>b.getUint16(x,le),u32=x=>b.getUint32(x,le);const out={};
    const ifd=(at,cb)=>{const n=u16(at);for(let i=0;i<n;i++){const e=at+2+i*12;cb(u16(e),u16(e+2),u32(e+4),e+8)}};
    const str=(off,cnt)=>{let r='';for(let i=0;i<cnt-1;i++)r+=String.fromCharCode(b.getUint8(t+off+i));return r};
    const rat=(off,i)=>u32(t+off+i*8)/(u32(t+off+i*8+4)||1);
    let exifAt=0,gpsAt=0;ifd(t+u32(t+4),(tag,ty,c,v)=>{if(tag===0x8769)exifAt=u32(v);if(tag===0x8825)gpsAt=u32(v)});
    if(exifAt)ifd(t+exifAt,(tag,ty,c,v)=>{if(tag===0x9003){const d=str(u32(v),c).match(/(\d+):(\d+):(\d+) (\d+):(\d+):(\d+)/);if(d)out.time=new Date(+d[1],d[2]-1,+d[3],+d[4],+d[5],+d[6])}});
    if(gpsAt){const g={};ifd(t+gpsAt,(tag,ty,c,v)=>{if(tag===1||tag===3)g[tag]=String.fromCharCode(b.getUint8(v));if(tag===2||tag===4){const off=u32(v);g[tag]=rat(off,0)+rat(off,1)/60+rat(off,2)/3600}});
      if(g[2]&&g[4])out.pos={lat:g[1]==='S'?-g[2]:g[2],lng:g[3]==='W'?-g[4]:g[4],src:'exif'}}
    return out}
    if((m&0xFF00)!==0xFF00)break;o+=2+len}}catch(e){}return{}}
/* ตำแหน่งปัจจุบัน (เก็บไว้ใช้ซ้ำ 60 วินาที) */
let POS=null;
function currentPos(){if(POS&&Date.now()-POS.at<60000)return Promise.resolve(POS);
  return new Promise(res=>{if(!navigator.geolocation)return res(null);navigator.geolocation.getCurrentPosition(g=>{POS={lat:g.coords.latitude,lng:g.coords.longitude,acc:Math.round(g.coords.accuracy),at:Date.now()};res(POS)},()=>res(null),{enableHighAccuracy:true,timeout:8000,maximumAge:30000})})}
/* ชื่อสถานที่จากพิกัด (OpenStreetMap) · ไม่ได้ภายใน 3 วินาทีใช้พิกัดอย่างเดียว */
const GEO={};
async function placeName(lat,lng){const k=lat.toFixed(4)+','+lng.toFixed(4);if(k in GEO)return GEO[k];
  try{const ac=new AbortController();const tm=setTimeout(()=>ac.abort(),3000);
    const r=await fetch('https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=16&accept-language=th&lat='+lat+'&lon='+lng,{signal:ac.signal});clearTimeout(tm);
    const a=(await r.json()).address||{};const n=[a.road||a.village||a.hamlet||a.neighbourhood,a.suburb||a.subdistrict||a.quarter,a.city_district||a.district||a.county||a.town,a.state||a.province||a.city].filter(Boolean);
    return GEO[k]=[...new Set(n)].join(' ')||null}catch(e){return GEO[k]=null}}
const fmtTH=d=>d.toLocaleString('th-TH',{timeZone:'Asia/Bangkok',day:'numeric',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit'});
/* ข้อความประทับ: เวลาถ่าย + สถานที่ + ข้อมูลงาน */
async function stampLines(file,extra){
  const ex=await readExif(file);const now=new Date();
  let shot=ex.time||(file.lastModified?new Date(file.lastModified):now);if(shot>now)shot=now;
  const old=now-shot>30*60000;
  const t=[(old?'ถ่าย ':'ถ่าย ')+fmtTH(shot)+(old?' · อัปโหลด '+now.toLocaleTimeString('th-TH',{timeZone:'Asia/Bangkok',hour:'2-digit',minute:'2-digit'})+' (รูปเก่า/จากคลังภาพ)':'')];
  const pos=ex.pos||(old?null:await currentPos());
  if(pos){const nm=await placeName(pos.lat,pos.lng);
    t.push((nm?nm+' · ':'')+pos.lat.toFixed(5)+', '+pos.lng.toFixed(5)+(pos.acc?' ±'+pos.acc+' ม.':'')+(pos.src==='exif'?' (จากรูป)':''))}
  else t.push(old?'ไม่ทราบตำแหน่งตอนถ่าย':'ไม่ทราบตำแหน่ง (ไม่ได้อนุญาต Location)');
  return [...t,...(extra||[]),'SafeStart · '+(ME&&(ME.full_name||ME.email)||'')]}
function wrapLines(g2,lines,w){const out=[];lines.forEach(l=>{let cur='';for(const ch of String(l)){if(g2.measureText(cur+ch).width>w&&cur){out.push(cur);cur=ch}else cur+=ch}if(cur)out.push(cur)});return out}
async function stamped(file,max,lines){
  const url=URL.createObjectURL(file);const im=await loadImg(url);URL.revokeObjectURL(url);
  const s=Math.min(1,max/Math.max(im.width,im.height));const c=document.createElement('canvas');c.width=Math.round(im.width*s);c.height=Math.round(im.height*s);
  const g2=c.getContext('2d');g2.drawImage(im,0,0,c.width,c.height);
  if(lines&&lines.length){const fs=Math.max(13,Math.round(Math.min(c.width,c.height*1.3)/36));g2.font=`600 ${fs}px "IBM Plex Sans Thai",sans-serif`;
    const L=wrapLines(g2,lines,c.width-fs*1.8);const h=fs*1.45*L.length+fs*.9;
    g2.fillStyle='rgba(10,16,28,.62)';g2.fillRect(0,c.height-h,c.width,h);g2.fillStyle='#F4B000';g2.fillRect(0,c.height-h,Math.max(4,fs/3),h);
    g2.fillStyle='#fff';L.forEach((t,i)=>{g2.font=`${i===0?700:500} ${fs}px "IBM Plex Sans Thai",sans-serif`;g2.fillText(t,fs*.9,c.height-h+fs*1.25+i*fs*1.45)})}
  return new Promise(r=>c.toBlob(r,'image/jpeg',.82));
}
const URLC={};
async function signedUrl(path,bucket){if(!path)return null;const k=(bucket||'photos')+'/'+path;const c=URLC[k];if(c&&c.exp>Date.now())return c.url;
  const {data,error}=await sb.storage.from(bucket||'photos').createSignedUrl(path,3600);if(error)return null;URLC[k]={url:data.signedUrl,exp:Date.now()+50*6e4};return data.signedUrl}
async function uploadPhoto(file,{folder,stamp,bucket,camera}={}){
  if(!file)throw new Error('ยังไม่ได้เลือกไฟล์');
  const isPdf=file.type==='application/pdf';if(!isPdf&&!/^image\//.test(file.type))throw new Error('รองรับเฉพาะรูปภาพหรือ PDF');
  // ประทับเวลาและสถานที่ทุกรูปหน้างาน (ยกเว้นรูปบัตรประชาชนและเอกสารสุขภาพ)
  const doStamp=!isPdf&&(stamp||camera)&&!['idcheck','health'].includes(bucket);
  const lines=doStamp?await stampLines(file,stamp):null;
  const body=isPdf?file:await stamped(file,1600,lines);
  const path=`${folder||ME.contractor_id||'scg'}/${today()}/${uid()}.${isPdf?'pdf':'jpg'}`;
  const {error}=await sb.storage.from(bucket||'photos').upload(path,body,{contentType:isPdf?'application/pdf':'image/jpeg'});
  if(error)throw new Error('อัปโหลดไม่สำเร็จ: '+error.message);return path;
}
function Img({path,bucket,cls,alt}){const [src,set]=useState(null);useEffect(()=>{let a=true;signedUrl(path,bucket).then(u=>a&&set(u));return()=>{a=false}},[path]);
  if(!path)return null;if(/\.pdf$/.test(path))return src?html`<a className="btn small" href=${src} target="_blank" rel="noopener">เปิด PDF</a>`:null;
  return src?html`<img className=${cls||'thumb'} src=${src} alt=${alt||'รูปหลักฐาน'} onClick=${()=>UI.zoom(src)}/>`:html`<div className=${cls||'thumb'} aria-hidden="true"></div>`}
function Upload({label,hint,value,onChange,stamp,camera,accept,bucket,folder,compact}){const [st,setSt]=useState('');
  const pick=async e=>{const f=e.target.files[0];e.target.value='';if(!f)return;setSt((stamp||camera)?'กำลังประทับเวลา/สถานที่ และอัปโหลด…':'กำลังอัปโหลด…');try{onChange(await uploadPhoto(f,{stamp,bucket,folder,camera}));setSt('')}catch(err){setSt(err.message)}};
  return html`<div className=${cx('photo',value&&'done',compact&&'compact')}>${value?html`<${Img} path=${value} bucket=${bucket}/>`:html`<div className="ic-circle mute"><${Ic} n="camera"/></div>`}
  <div className="grow"><div style=${{fontWeight:500}}>${label}</div><div className="sm muted">${st||hint||(value?'แนบแล้ว':camera?'ถ่ายจากกล้องหน้างาน':'')}</div></div>
  <label className=${cx('btn small upbtn',!value&&'dark')}>${value?'เปลี่ยน':camera?'ถ่ายรูป':'แนบไฟล์'}<input type="file" accept=${accept||'image/*'} capture=${camera?'environment':undefined} onChange=${pick}/></label></div>`}

/* เสียงอ่าน 4 ภาษา */
const LANGS=[['th','ไทย','th-TH'],['my','မြန်မာ','my-MM'],['km','ខ្មែរ','km-KH'],['lo','ລາວ','lo-LA']];
function speak(t,lang){try{speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(t);const L=(LANGS.find(x=>x[0]===(lang||'th'))||LANGS[0])[2];u.lang=L;
  const v=speechSynthesis.getVoices().find(x=>x.lang&&x.lang.toLowerCase().startsWith(L.slice(0,2)));if(v)u.voice=v;else if(lang&&lang!=='th')UI.toast('เครื่องนี้ไม่มีเสียงภาษานี้ อ่านเป็นข้อความแทน');speechSynthesis.speak(u)}catch(e){UI.toast('อุปกรณ์นี้อ่านออกเสียงไม่ได้')}}
const tr=(o,lang)=>!o?'':lang&&lang!=='th'&&o.t&&o.t[lang]?o.t[lang]:o.text;
