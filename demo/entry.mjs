// SafeStart เดโม: บูต Postgres (PGlite) ในเบราว์เซอร์ แล้วติดตั้ง schema + ข้อมูลตัวอย่าง
import {PGlite,types} from '@electric-sql/pglite';
import {createDemoClient} from './pgclient.mjs';
import STUB from '../test/stub.sql';import SCHEMA from '../supabase/schema.sql';import SEED from '../supabase/seed.sql';import DEMO from '../test/demo_seed.sql';
const iso=v=>{const s=String(v).replace(' ','T').replace(/([+-]\d\d)$/,'$1:00');const d=new Date(s);return isNaN(d)?v:d.toISOString()};
const b64blob=t=>{const s=atob(t.trim());const u=new Uint8Array(s.length);for(let i=0;i<s.length;i++)u[i]=s.charCodeAt(i);return new Blob([u])};
const prog=t=>{window.DEMO_PROGRESS=t;window.dispatchEvent(new Event('demo-progress'))};
const dbP=(async()=>{
  prog('กำลังดาวน์โหลดฐานข้อมูลตัวอย่าง (ครั้งแรกประมาณ 15 MB)…');
  const [wasm,data]=await Promise.all([fetch('pglite.wasm').then(r=>{if(!r.ok)throw new Error('โหลด pglite.wasm ไม่ได้');return r.arrayBuffer()}).then(b=>WebAssembly.compile(b)),fetch('pglite-data.txt').then(r=>r.text()).then(b64blob)]);
  prog('กำลังเปิดฐานข้อมูล…');
  const cr=await fetch('pgcrypto.txt').then(r=>r.text()).then(b64blob);const crURL=URL.createObjectURL(cr);
  const pgcrypto={name:'pgcrypto',setup:async()=>({bundlePath:new URL(crURL)})};
  const db=await PGlite.create({wasmModule:wasm,fsBundle:data,extensions:{pgcrypto},
    parsers:{[types.DATE]:v=>v,[types.TIMESTAMPTZ]:iso,[types.TIMESTAMP]:v=>v,1083:v=>v,[types.NUMERIC]:v=>Number(v),[types.INT8]:v=>Number(v)}});
  prog('กำลังติดตั้งระบบและข้อมูลตัวอย่าง…');
  await db.exec(STUB.replace(/create publication[^;]*;/gi,'null;'));await db.exec('create extension if not exists pgcrypto with schema extensions');
  await db.exec(SCHEMA);await db.exec(SEED);await db.exec(DEMO);prog('');return db})();
const PH={team:['รูปทีมรวม','#2F6FA8'],site:['จุดทำงาน','#3C7D5C'],fail:['จุดที่ไม่ผ่าน','#B4412F'],fixed:['หลังแก้ไข','#2E8B57'],after:['หลังเลิกงาน','#5C6B7F'],idcard:['บัตร (ชั่วคราว)','#7A5BA6'],cert:['เอกสาร/ใบรับรอง','#9A7B2F'],face:['รูปหน้าช่าง','#4A6A8A'],health:['หน้าจอเครื่องวัด','#2B7A8C'],anchor:['จุดยึด/ทางเดิน','#C9520A']};
function placeholder(path){const k=(path.match(/demo\/([a-z]+)/)||[])[1]||'site';const L=PH[k]||['รูปหลักฐาน','#5C6B7F'];
  const art=k==='team'?'<g fill="#fff" opacity=".9"><circle cx="190" cy="150" r="26"/><rect x="160" y="182" width="60" height="70" rx="20"/><circle cx="270" cy="140" r="28"/><rect x="238" y="174" width="64" height="78" rx="20"/><circle cx="350" cy="150" r="26"/><rect x="320" y="182" width="60" height="70" rx="20"/><path d="M164 130h52v-10a26 26 0 0 0-52 0zM242 118h56v-10a28 28 0 0 0-56 0zM324 130h52v-10a26 26 0 0 0-52 0z" fill="#E2600C"/></g>'
    :k==='face'?'<g fill="#fff" opacity=".9"><circle cx="280" cy="140" r="50"/><rect x="200" y="200" width="160" height="90" rx="40"/></g>'
    :k==='idcard'?'<rect x="150" y="90" width="260" height="160" rx="14" fill="#fff" opacity=".92"/><rect x="170" y="120" width="70" height="90" rx="6" fill="#ccd"/><rect x="255" y="125" width="130" height="12" rx="6" fill="#ccd"/><rect x="255" y="150" width="100" height="12" rx="6" fill="#ccd"/>'
    :k==='cert'?'<rect x="200" y="60" width="160" height="210" rx="8" fill="#fff" opacity=".92"/><rect x="225" y="95" width="110" height="10" rx="5" fill="#ccd"/><rect x="225" y="120" width="90" height="8" rx="4" fill="#ccd"/><circle cx="280" cy="215" r="22" fill="#E2600C"/>'
    :k==='health'?'<rect x="200" y="60" width="160" height="210" rx="20" fill="#fff" opacity=".92"/><text x="280" y="150" text-anchor="middle" font-size="44" font-family="monospace" fill="#2B7A8C">120/80</text><text x="280" y="200" text-anchor="middle" font-size="26" font-family="monospace" fill="#2B7A8C">♥ 78</text>'
    :'<path d="M120 250 L280 120 L440 250 Z" fill="#fff" opacity=".9"/><rect x="170" y="240" width="220" height="40" fill="#fff" opacity=".75"/>'+(k==='fail'?'<circle cx="360" cy="150" r="46" fill="none" stroke="#FFD24A" stroke-width="8"/>':k==='fixed'?'<path d="M330 150l22 22 42-46" stroke="#FFD24A" stroke-width="10" fill="none"/>':'');
  const svg='<svg xmlns="http://www.w3.org/2000/svg" width="560" height="340" viewBox="0 0 560 340"><rect width="560" height="340" fill="'+L[1]+'"/>'+art+'<rect y="296" width="560" height="44" fill="rgba(10,16,28,.6)"/><rect y="296" width="6" height="44" fill="#E2600C"/><text x="18" y="324" fill="#fff" font-family="sans-serif" font-size="18">ตัวอย่าง · '+L[0]+'</text></svg>';
  return'data:image/svg+xml;charset=utf-8,'+encodeURIComponent(svg)}
const demo=createDemoClient(dbP,{placeholder});
window.SAFESTART_DEMO=true;window.SAFESTART_CONFIG={SUPABASE_URL:'https://demo.safestart.local',SUPABASE_ANON_KEY:'demo',LINE_OA_ID:'@safestart',VAPID_PUBLIC_KEY:''};
window.supabase={createClient:()=>demo.client};window.DEMO=demo;
dbP.catch(e=>{console.error(e);prog('เปิดฐานข้อมูลตัวอย่างไม่สำเร็จ: '+e.message)});
