/* SafeStart · โหมดเดโม: เลือกบทบาท แถบสลับบทบาท รูปตัวอย่าง ตำแหน่งและอากาศจำลอง */
const DEMO_USERS=[
  [6,'หัวหน้าทีมช่าง','สมชาย · ทีม A บจ.ช่างดีการช่าง','wah','Check-in งานหลังคา PO-24001 ครบทุกขั้น: อากาศ ตรวจสุขภาพ เช็กลิสต์ภาพ 4 ภาษา → บัตรส้ม → ส่งรูปจุดยึด → บัตรเขียว · กด SOS ค้าง'],
  [5,'ผู้ดูแลบริษัทผู้รับเหมา','บอส · บจ.ช่างดีการช่าง (2 บริษัท SCG)','building','ยื่นแผน PO-24005 · เพิ่มช่างและขอเข้าทำงานกับแต่ละบริษัท · Self-declaration · เอกสารบริษัท · ดูทุกบริษัทพร้อมกัน'],
  [3,'Installation Consultant','วิภา · SCG Home Experience','map','กระดานวันนี้ + อากาศเสี่ยง · อนุมัติใบอนุญาต PO-24004 · สแกนบัตรผ่าน · สั่งหยุด/ปลดล็อก'],
  [2,'Purchasing','กานดา · SCG Home Experience','inbox','ตรวจตัวบุคคล (เก็บแค่เลขท้าย + hash) อนุมัติช่าง · ค้นผู้รับเหมาด้วยเลขภาษี เห็น Flag LSR · นำเข้า PO จับคู่คอลัมน์'],
  [1,'SCG Safety (Admin)','ศรายุทธ · 2 บริษัท + ผู้ดูแลระบบ','shield','สลับบริษัท · ตั้งค่าโครงการ ประเภทงาน กติกา/อากาศ เช็กลิสต์ · รับรองใบแพทย์ · บันทึกโทษ LSR'],
  [11,'หัวหน้าทีม (เข้าครั้งแรก)','ชาญ · หจก.พรีเมียร์รูฟ','user','เห็นหน้ายินยอม PDPA ก่อนใช้ · บัตรส้มงานโซลาร์ PO-24003 ใกล้หมดเวลา'],
  [9,'ผู้บริหาร','SCG Home Experience','report','กระดานวันนี้และ Findings แบบอ่านอย่างเดียว'],
  [7,'IC บริษัทอื่น','ปรีชา · SCG Distribution','building','เห็นเฉพาะงานของ SCG Distribution · ไม่เห็นข้อมูลบริษัทอื่น']];
const uidOf=n=>'a0000000-0000-0000-0000-0000000000'+String(n).padStart(2,'0');
try{lsSet('ss.installed',1)}catch(e){}
function DemoPicker({pick,ready}){return html`<div className="land" style=${{alignItems:'start'}}><${BgArt} k="city"/><div className="land-in" style=${{maxWidth:820}}>
  <div className="logo big"><div className="logo-mark"><${Ic} n="shield"/></div><div><span className="eyebrow" style=${{color:'var(--brand)'}}>ตัวอย่างระบบจริง · Phase 1</span><b>SafeStart</b></div></div>
  <p style=${{color:'#C9D4E5'}}>เลือกบทบาทเพื่อลองหน้าจอจริงของระบบ ฐานข้อมูลเป็น Postgres ตัวเดียวกับของจริงที่รันในเบราว์เซอร์ กติกาและสิทธิ์ทำงานเหมือนจริง · <b>ข้อมูลไม่ถูกบันทึกออกไปไหน รีเฟรชแล้วเริ่มใหม่</b></p>
  ${!ready?html`<div className="card pad sm">${window.DEMO_PROGRESS||'กำลังเตรียม…'}</div>`:null}
  <div className="g2">${DEMO_USERS.map(([n,role,who,ic,what])=>html`<button key=${n} className="whob" disabled=${!ready} style=${{alignItems:'flex-start',opacity:ready?1:.6}} onClick=${()=>pick(uidOf(n))}>
    <span className="ic" style=${{width:44,height:44}}><${Ic} n=${ic}/></span><span className="grow"><b style=${{fontSize:16}}>${role}</b><span style=${{display:'block'}}>${who}</span><span style=${{display:'block',marginTop:6,color:'var(--ink-2)'}}>${what}</span></span></button>`)}</div>
  <div className="xs" style=${{color:'#8FA2BF'}}>ระบบจริงเข้าด้วยอีเมล + รหัส 6 หลัก (หน้าแรก 2 ปุ่ม) · หน้านี้ข้ามขั้นตอนนั้นให้ · พยากรณ์อากาศและตำแหน่ง GPS เป็นค่าจำลอง</div></div></div>`}
function DemoBar({id,pick}){const [o,setO]=useState(false);const u=DEMO_USERS.find(x=>uidOf(x[0])===id);
  return html`<div className="demo-pill">${o?html`<div className="card pad col tight" style=${{boxShadow:'var(--shadow-3)',width:270}}><b className="sm">ดูในบทบาท</b>${DEMO_USERS.map(([n,r,w])=>html`<button key=${n} className=${'btn small block'+(uidOf(n)===id?' primary':'')} style=${{justifyContent:'flex-start'}} onClick=${()=>{setO(false);pick(uidOf(n))}}>${r}</button>`)}
      <button className="btn small ghost block" onClick=${()=>{setO(false);pick(null)}}>กลับหน้าเลือกบทบาท</button><button className="btn small ghost block" onClick=${()=>location.reload()}>เริ่มข้อมูลใหม่</button></div>`:null}
    <button className="btn small dark" style=${{borderRadius:999,boxShadow:'var(--shadow-3)'}} onClick=${()=>setO(x=>!x)}>เดโม · ${u?u[1]:''} ▾</button></div>`}
function DemoRoot(){const [id,setId]=useState(null);const [k,setK]=useState(0);const [ready,setReady]=useState(false);const [,f]=useState(0);
  useEffect(()=>{const g=()=>f(x=>x+1);window.addEventListener('demo-progress',g);DEMO.ready.then(()=>setReady(true)).catch(()=>{});return()=>window.removeEventListener('demo-progress',g)},[]);
  const pick=u=>{DEMO.setUser(u);ME=null;S.ready=false;S.co=null;setId(u);setK(x=>x+1);try{history.replaceState(null,'',location.pathname)}catch(e){}window.scrollTo(0,0)};
  window.DEMO_SWITCH=pick;
  if(!id)return html`<${DemoPicker} pick=${pick} ready=${ready}/>`;
  return html`<${Fragment}><${App} key=${k}/><${DemoBar} id=${id} pick=${pick}/></${Fragment}>`}

/* ทางลัด: ใช้รูปตัวอย่างแทนการถ่ายจริง */
const _Upload=Upload;
Upload=function(p){const l=p.label||'';const g=/ทีม/.test(l)?'team':/หลังแก้/.test(l)?'fixed':/ไม่ผ่าน/.test(l)?'fail':/เลิกงาน/.test(l)?'after':/บัตร/.test(l)?'idcard':/เครื่องวัด/.test(l)?'health':/รูป (H|CE)/.test(l)?'anchor':/หน้าช่าง/.test(l)?'face':/cert|ใบ|ผล|เอกสาร|ไฟล์/.test(l)?'cert':'site';
  return html`<div className="col tight"><${_Upload} ...${p}/>${!p.value?html`<button type="button" className="btn ghost small" style=${{alignSelf:'flex-end'}} onClick=${()=>p.onChange('demo/'+g+'-'+uid()+'.jpg')}>ใช้รูปตัวอย่าง (เดโม)</button>`:null}</div>`};
/* ตำแหน่งจำลอง: ใกล้บ้านของงานวันนี้ */
try{Object.defineProperty(navigator,'geolocation',{configurable:true,value:{getCurrentPosition:(ok)=>{const j=(window.S&&S.jobs||[]).find(x=>x.id===window.__demoJob)||{lat:13.6672,lng:100.6501};setTimeout(()=>ok({coords:{latitude:j.lat+0.0002,longitude:j.lng+0.0001,accuracy:12}}),300)}}})}catch(e){}
const _CI=CheckinSheet;CheckinSheet=function(p){window.__demoJob=p.id;return _CI(p)};
/* พยากรณ์จำลอง: บางนามีพายุบ่าย · บางแสนร้อน · ที่อื่นปกติ */
fetchWeather=async pts=>pts.map(([lat])=>{const d=today();const time=[],t=[],rh=[],pp=[],pr=[],gu=[],wc=[];const bn=Math.abs(lat-13.67)<.05,bs=Math.abs(lat-13.28)<.05;
  for(let h=0;h<24;h++){time.push(d+'T'+z(h)+':00');t.push(bs?(h>=11&&h<=15?35:30):32);rh.push(bs?70:55);pp.push(bn&&h>=13&&h<=16?75:15);pr.push(bn&&h===14?3:0);gu.push(bn&&h===13?44:16);wc.push(bn&&h===14?95:2)}
  return{time,temperature_2m:t,relative_humidity_2m:rh,precipitation_probability:pp,precipitation:pr,wind_gusts_10m:gu,weather_code:wc}});
ReactDOM.createRoot(document.getElementById('root')).render(html`<${DemoRoot}/>`);
