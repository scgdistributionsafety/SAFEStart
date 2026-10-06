/* SafeStart · หน้าแรก เข้าระบบ เลือกบริษัท โครงหน้าเว็บ และเมนู (main.js) */

function Landing({go}){return html`<div className="land"><${BgArt} k="city"/><div className="land-in">
  <div className="logo big"><div className="logo-mark"><${Ic} n="shield"/></div><div><span className="eyebrow" style=${{color:'var(--brand)'}}>SCG · CONTRACTOR SAFETY</span><b>SafeStart</b></div></div>
  <h1>ปลอดภัยก่อนเริ่มงานทุกวัน</h1><p className="muted">Safety Check-in · ใบอนุญาตทำงาน · บัตรผ่าน · ทีมและช่าง สำหรับงานติดตั้งหน้าบ้านลูกค้า</p>
  <div className="who"><div className="eyebrow">คุณคือใคร</div>
    <button className="whob" onClick=${()=>go('contractor')}><span className="ic"><${Ic} n="wah"/></span><span className="grow"><b>ผู้รับเหมา / หัวหน้าช่าง</b><span>Check-in · บัตรผ่าน · ทีมและช่าง</span></span><${Ic} n="chev"/></button>
    <button className="whob scg" onClick=${()=>go('scg')}><span className="ic"><${Ic} n="building"/></span><span className="grow"><b>พนักงาน SCG</b><span>กระดานวันนี้ · อนุมัติ · รายงาน</span></span><${Ic} n="chev"/></button></div>
  <div className="row sm"><button className="link" onClick=${()=>go('help')}>คู่มือการใช้งาน</button><span className="muted">·</span><button className="link" onClick=${()=>go('privacy')}>นโยบายข้อมูลส่วนบุคคล</button></div></div></div>`}

function Login({who,back}){const [e,setE]=useState(lsGet('ss.email')||'');const [sent,setSent]=useState(false);const [code,setCode]=useState('');const [err,setErr]=useState('');
  const send=async()=>{setErr('');const {error}=await sb.auth.signInWithOtp({email:e.trim().toLowerCase(),options:{shouldCreateUser:true,emailRedirectTo:location.origin+location.pathname}});
    if(error)return setErr(errMsg(error));lsSet('ss.email',e.trim().toLowerCase());setSent(true)};
  const verify=async()=>{setErr('');const {error}=await sb.auth.verifyOtp({email:e.trim().toLowerCase(),token:code.trim(),type:'email'});if(error)setErr('รหัสไม่ถูกต้องหรือหมดอายุ')};
  return html`<div className="auth"><div className="auth-card card pad col">
    <button className="btn ghost small" style=${{justifySelf:'start'}} onClick=${back}><${Ic} n="back"/>กลับ</button>
    <div className="row"><span className="ic-circle brand"><${Ic} n=${who==='scg'?'building':'wah'}/></span><div><h2>${who==='scg'?'พนักงาน SCG':'ผู้รับเหมา / หัวหน้าช่าง'}</h2><div className="sm muted">${who==='scg'?'ใช้อีเมลบริษัทที่ Safety Admin เชิญไว้':'ใช้อีเมลที่ผู้ดูแลบริษัทหรือ SCG เชิญไว้ (บัญชีรายคน)'}</div></div></div>
    ${!sent?html`<${Field} label="อีเมล"><${Inp} type="email" v=${e} set=${setE} ph="name@company.com"/></${Field}>
      <${Btn} kind="primary" big=${true} block=${true} disabled=${!/.+@.+\..+/.test(e)} onClick=${send}>ส่งรหัสเข้าสู่ระบบ</${Btn}>`
    :html`<div className="sm">ส่งรหัส 6 หลักไปที่ <b>${e}</b> แล้ว (หรือกดลิงก์ในอีเมลก็ได้)</div><${Field} label="รหัสจากอีเมล"><${Inp} v=${code} set=${setCode} mode="numeric" max=${6} ph="••••••"/></${Field}>
      <${Btn} kind="primary" big=${true} block=${true} disabled=${code.trim().length<6} onClick=${verify}>เข้าสู่ระบบ</${Btn}><button className="btn ghost" onClick=${()=>setSent(false)}>เปลี่ยนอีเมล</button>`}
    ${err?html`<div className="sm" style=${{color:'var(--stop)'}}>${err}</div>`:null}
    <div className="xs muted">บทบาทและสิทธิ์มาจากคำเชิญเท่านั้น ปุ่มที่เลือกเปลี่ยนแค่คำแนะนำ</div></div></div>`}

const PDPA_FALLBACK={version:'-',title:'การเก็บและใช้ข้อมูลส่วนบุคคล',paragraphs:['SafeStart เก็บข้อมูลเท่าที่จำเป็นเพื่อดูแลความปลอดภัยในการทำงาน รายละเอียดฉบับเต็มแสดงหลังเข้าสู่ระบบ']};
function PrivacyText({p}){p=p||PDPA_FALLBACK;return html`<div className="col tight"><h3>${p.title}</h3>${p.paragraphs.map((x,i)=>html`<p key=${i} className="sm">${x}</p>`)}<div className="xs muted">ฉบับ ${p.version}</div></div>`}
function Pdpa({p,done}){const [ok,setOk]=useState(false);return html`<div className="auth"><div className="auth-card card pad col"><span className="ic-circle info"><${Ic} n="lock"/></span><${PrivacyText} p=${p}/>
  <${Check} on=${ok} set=${setOk}>อ่านและยินยอมให้เก็บและใช้ข้อมูลตามที่ระบุ</${Check}>
  <${Btn} kind="primary" big=${true} block=${true} disabled=${!ok} onClick=${async()=>{if(await run(()=>rpc('accept_pdpa',{p_version:p.version})))done()}}>ยินยอมและเริ่มใช้งาน</${Btn}>
  <button className="btn ghost" onClick=${()=>sb.auth.signOut()}>ไม่ยินยอม · ออกจากระบบ</button></div></div>`}
function InstallHint({done}){const ios=/iphone|ipad/i.test(navigator.userAgent);const [ev,setEv]=useState(window.__bip||null);useEffect(()=>{const f=e=>{e.preventDefault();window.__bip=e;setEv(e)};window.addEventListener('beforeinstallprompt',f);return()=>window.removeEventListener('beforeinstallprompt',f)},[]);
  return html`<div className="auth"><div className="auth-card card pad col"><span className="ic-circle brand"><${Ic} n="phone"/></span><h2>ติดตั้ง SafeStart บนหน้าจอมือถือ</h2>
    <p className="sm">เปิดเร็วเหมือนแอป เต็มจอ และรับแจ้งเตือนบนเครื่องได้ (ฟรี ไม่ต้องโหลดจาก Store)</p>
    ${ev?html`<${Btn} kind="primary" big=${true} block=${true} onClick=${async()=>{ev.prompt();await ev.userChoice;done()}}>ติดตั้งเลย</${Btn}>`:html`<ol className="sm">${ios?html`<li>กดปุ่มแชร์ <b>⬆︎</b> ด้านล่างของ Safari</li><li>เลือก <b>เพิ่มไปยังหน้าจอโฮม</b></li>`:html`<li>กดเมนู <b>⋮</b> มุมขวาบนของ Chrome</li><li>เลือก <b>ติดตั้งแอป</b> หรือ <b>เพิ่มลงในหน้าจอหลัก</b></li>`}</ol>`}
    <button className="btn ghost" onClick=${done}>ข้ามไปก่อน</button></div></div>`}

function CompanyPicker({pick}){useStore();const cos=myCos();
  return html`<div className="auth"><div className="auth-card col" style=${{maxWidth:620}}><div className="card pad col tight"><h2>สวัสดี ${ME.full_name||''}</h2><div className="sm muted">${isContractor()?ctrName(ME.contractor_id)+' · ':''}เลือกบริษัท SCG ที่จะดูงาน · สลับได้ตลอดจากแถบสีใต้หัวจอ</div></div>
    ${cos.map(c=>{const js=S.jobs.filter(j=>j.scg_company_id===c&&isToday(j));const l=isContractor()&&ctrLink(ME.contractor_id,c);const ws=isContractor()?S.workers.filter(w=>w.contractor_id===ME.contractor_id):[];const ap=ws.filter(w=>linkOf(w.id,c)?.status==='approved').length;const pend=ws.filter(w=>linkOf(w.id,c)?.status==='pending').length;
      return html`<button key=${c} className="cocard" style=${{'--co':coColor(c)}} onClick=${()=>pick(c)}><div className="grow"><b>${coName(c)}</b><div className="sm muted">งานวันนี้ ${js.length}${isContractor()?' · ช่างที่อนุมัติ '+ap+'/'+ws.length:''}</div></div>
        ${l?html`<${Chip} c=${l.status==='approved'?'go':l.status==='pending'?'warn':'stop'} t=${l.status==='approved'?(pend?'รออนุมัติช่าง '+pend:'อนุมัติแล้ว'):l.status==='pending'?'รออนุมัติบริษัท':'ถูกพัก'}/>`:null}<${Ic} n="chev"/></button>`})}
    ${isContractor()&&cos.length>1?html`<button className="cocard all" onClick=${()=>pick('all')}><div className="grow"><b>ทุกบริษัท</b><div className="sm muted">รวมงานวันนี้ ${S.jobs.filter(isToday).length} · มีป้ายบอกบริษัทบนทุกการ์ด</div></div><${Ic} n="chev"/></button>`:null}</div></div>`}

function PublicPass({token}){const [r,setR]=useState(null);useEffect(()=>{sb.rpc('verify_pass',{p_token:token}).then(({data})=>setR(data||{valid:false}))},[token]);
  return html`<div className="auth"><div className="auth-card col">${!r?html`<div className="muted">กำลังตรวจสอบ…</div>`:html`<${PassResult} r=${r}/>`}<div className="xs muted" style=${{textAlign:'center'}}>ตรวจสอบโดย SafeStart · SCG</div></div></div>`}

function Help(){const role=ME?ME.role:'';const C=[['เริ่มวันทำงาน','เปิดหน้าหลัก → การ์ดงานวันนี้ → เริ่ม Safety Check-in → ทำตามขั้นจนได้บัตรผ่าน'],['บัตรส้ม/เขียว','งานที่สูงต้องติดจุดยึดก่อน: บัตรส้มให้เฉพาะคนติดตั้งขึ้น ส่งรูปภายใน 60 นาทีแล้วเป็นบัตรเขียว'],['ตรวจสุขภาพ','คนที่ขึ้นที่สูงวัดชีพจร ความดัน แอลกอฮอล์ทุกวัน นอกเกณฑ์พัก 15 นาทีวัดซ้ำ'],['ปิดงาน','ทุกวันก่อนกลับ: ตอบข้อปิดงาน ถ่ายรูป 2 รูป · ไม่ปิดงานจะ check-in วันถัดไปไม่ได้'],['SOS','กดปุ่มแดงค้าง 1 วินาที ระบบแจ้ง IC Safety ผู้ดูแลบริษัทพร้อมพิกัด และแสดงเบอร์ฉุกเฉิน']];
  const S2=[['กระดานวันนี้','สีหมุดบอกสถานะ ขอบหนา = เสี่ยงสูง ⛈ = อากาศเสี่ยงสำหรับงานที่สูง'],['อนุมัติงานเสี่ยงสูง','กล่องงาน → ใบอนุญาต → ดูคำถามหน้างานและความพร้อมช่าง → อนุมัติ/ตีกลับ'],['ตรวจตัวบุคคล','ดูรูปบัตรชั่วคราว ใส่เลขบัตร ระบบเก็บเลขท้าย 4 หลักและรหัสทางเดียว แล้วลบรูป'],['สแกนบัตรผ่าน','เมนูสแกน → เปิดกล้อง → เทียบรายชื่อกับคนหน้างาน'],['นำเข้า PO','แผนงาน → นำเข้า → เลือกไฟล์ → จับคู่คอลัมน์ครั้งแรก ระบบจำไว้']];
  return html`<div className="col" style=${{maxWidth:760}}>${(!ME||isContractor())?html`<${Card}><${CardH} icon="wah" title="ผู้รับเหมา / หัวหน้าช่าง"/><div className="card-b col tight">${C.map(([a,b])=>html`<div key=${a}><b>${a}</b><div className="sm muted">${b}</div></div>`)}</div></${Card}>`:null}
    ${(!ME||isSCG())?html`<${Card}><${CardH} icon="building" title="พนักงาน SCG"/><div className="card-b col tight">${S2.map(([a,b])=>html`<div key=${a}><b>${a}</b><div className="sm muted">${b}</div></div>`)}</div></${Card}>`:null}
    <div className="xs muted">${role?ROLE_NAME[role]:''}</div></div>`}

/* ---------- เมนูตามบทบาท ---------- */
const NAV={
  team_lead:[['today','หน้าหลัก','home'],['jobs','งาน','cal'],['fab','Check-in','check'],['todo','ต้องแก้','warn'],['me','ฉัน','user']],
  contractor_admin:[['today','หน้าหลัก','home'],['jobs','งาน','cal'],['fab','Check-in','check'],['todo','ต้องแก้','warn'],['team','ทีมและช่าง','team'],['company','บริษัท','building'],['help','คู่มือ','book'],['me','ฉัน','user']],
  scg:[['board','หน้าหลัก','home'],['inbox','กล่องงาน','inbox'],['plan','แผนงาน/PO','cal'],['findings','Findings/เหตุ','flag'],['contractors','ผู้รับเหมา','building'],['scan','สแกนบัตรผ่าน','scan'],['settings','ตั้งค่า','cog'],['help','คู่มือ','book'],['me','ฉัน','user']]};
const TITLES={today:'หน้าหลัก',jobs:'งาน',todo:'ต้องแก้',team:'ทีมและช่าง',company:'บริษัทของฉัน',me:'บัญชีของฉัน',board:'กระดานวันนี้',inbox:'กล่องงาน',plan:'แผนงานและนำเข้า PO',findings:'Findings และเหตุการณ์',contractors:'ผู้รับเหมา',scan:'สแกนบัตรผ่าน',settings:'ตั้งค่า',help:'คู่มือการใช้งาน'};
const VIEW={today:CToday,jobs:CJobs,todo:CTodo,team:CTeam,company:CCompany,me:Me,board:SBoard,inbox:SInbox,plan:SPlan,findings:SFindings,contractors:SContractors,scan:SScan,settings:SSettings,help:Help};
function navFor(){if(!isSCG())return NAV[ME.role]||NAV.team_lead;return NAV.scg.filter(([id])=>(id!=='settings'||isSafety()||ME.is_owner)&&(id!=='scan'||canScan())&&(ME.role!=='executive'||['board','findings','contractors','help','me'].includes(id)))}

async function enablePush(){if(!('serviceWorker' in navigator)||!('PushManager' in window))throw new Error('เบราว์เซอร์นี้ไม่รองรับการแจ้งเตือน (iPhone ต้องติดตั้งแอปบนหน้าจอก่อน)');
  if(!CFG.VAPID_PUBLIC_KEY)throw new Error('ผู้ดูแลระบบยังไม่ได้ตั้งค่าการแจ้งเตือนบนเครื่อง');
  const perm=await Notification.requestPermission();if(perm!=='granted')throw new Error('ไม่ได้รับอนุญาตให้แจ้งเตือน');
  const reg=await navigator.serviceWorker.ready;const key=Uint8Array.from(atob(CFG.VAPID_PUBLIC_KEY.replace(/-/g,'+').replace(/_/g,'/')+'=='.slice(0,(4-CFG.VAPID_PUBLIC_KEY.length%4)%4)),c=>c.charCodeAt(0));
  const sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:key});const j=sub.toJSON();
  const {error}=await sb.from('push_subs').upsert({user_id:ME.id,endpoint:j.endpoint,keys:j.keys},{onConflict:'endpoint'});if(error)throw error}
function Me(){useStore();const [n,setN]=useState(ME.full_name||'');const [ph,setPh]=useState(ME.phone||'');const [code,setCode]=useState(ME.line_link_code||'');const [pv,setPv]=useState(false);
  return html`<div className="col" style=${{maxWidth:680}}><${Card} pad=${true} className="col"><div className="row"><${Avatar} n=${ME.full_name||ME.email} lg=${true}/><div><h3>${ME.full_name||ME.email}</h3><div className="sm muted">${ROLE_NAME[ME.role]}${ME.contractor_id?' · '+ctrName(ME.contractor_id):''}</div><div className="xs muted">${ME.email}${isSCG()?' · '+myCos().map(coShort).join(', '):''}</div></div></div>
    <div className="fgrid"><${Field} label="ชื่อ-นามสกุล"><${Inp} v=${n} set=${setN}/></${Field}><${Field} label="เบอร์โทร (แสดงในหน้า SOS ของผู้รับเหมา)"><${Inp} v=${ph} set=${setPh} mode="tel"/></${Field}></div><${Btn} onClick=${()=>act(()=>rpc('update_me',{p_name:n,p_phone:ph}),'บันทึกแล้ว')}>บันทึก</${Btn}></${Card}>
    <${Card} pad=${true} className="col tight"><b>แจ้งเตือนบนเครื่องนี้ (ฟรี · ช่องทางหลัก)</b><div className="sm muted">เรื่องที่ต้องรับทราบและเรื่องด่วนส่ง LINE เพิ่ม</div><${Btn} kind="dark" icon="bell" onClick=${()=>run(enablePush,'เปิดแจ้งเตือนบนเครื่องนี้แล้ว')}>เปิดแจ้งเตือนบนเครื่องนี้</${Btn}></${Card}>
    <${Card} pad=${true} className="col tight"><b>รับแจ้งเตือนทาง LINE</b>${ME.line_user_id?html`<${Chip} c="go" t="ผูก LINE แล้ว"/>`:html`<div className="sm">1) เพิ่มเพื่อน LINE OA ของ SafeStart${CFG.LINE_OA_ID?html` (<b>${CFG.LINE_OA_ID}</b>)`:''}  2) กดขอรหัส  3) พิมพ์รหัสส่งในแชต</div>
      <div className="row"><${Btn} kind="dark" onClick=${()=>act(async()=>setCode(await rpc('line_link_code')))}>ขอรหัสผูก LINE</${Btn}>${code?html`<span className="code">${code}</span>`:null}</div>`}</${Card}>
    <div className="row"><${Btn} icon="swap" onClick=${()=>UI.pickCo()}>เปลี่ยนบริษัทที่ดู</${Btn}><${Btn} onClick=${()=>{const t=document.documentElement.dataset.theme==='dark'?'light':'dark';document.documentElement.dataset.theme=t;lsSet('ss.theme',t)}}>สลับโหมดมืด/สว่าง</${Btn}>
      <${Btn} onClick=${()=>{const s=(lsGet('ss.fs')||15)+1>19?14:(lsGet('ss.fs')||15)+1;lsSet('ss.fs',s);document.body.style.fontSize=s+'px'}}>ขนาดตัวอักษร</${Btn}><${Btn} icon="lock" onClick=${()=>setPv(x=>!x)}>นโยบายข้อมูล</${Btn}><${Btn} kind="danger" icon="logout" onClick=${()=>sb.auth.signOut()}>ออกจากระบบ</${Btn}></div>
    ${pv?html`<${Card} pad=${true}><${PrivacyText} p=${sett('pdpa',null)}/><div className="xs muted">ยินยอมเมื่อ ${thT(ME.pdpa_at)}</div></${Card}>`:null}</div>`}

function NotifPanel({onClose}){useStore();const list=S.notifs.slice(0,40);return html`<div className="popover" style=${{right:16,top:70}}><div className="between" style=${{padding:'12px 16px',borderBottom:'1px solid var(--line)'}}><b>การแจ้งเตือน</b><button className="btn ghost small" onClick=${onClose}>ปิด</button></div>
  <div style=${{overflow:'auto',padding:'8px 16px'}} className="col tight">${list.length?list.map(n=>html`<${NotifRow} key=${n.id} n=${n}/>`):html`<div className="sm muted">ยังไม่มี</div>`}</div></div>`}

function CompanyBand(){useStore();const cos=myCos();if(!S.co)return null;const all=S.co==='all';const c=!all&&coOf(S.co);
  return html`<button className="coband" style=${{'--co':all?'var(--ink-2)':coColor(S.co)}} onClick=${()=>cos.length>1&&UI.pickCo()} aria-label="สลับบริษัท"><span className="dotc"></span><span className="grow">${all?'ทุกบริษัท SCG':c?c.name:''}</span>${cos.length>1?html`<span className="sw"><${Ic} n="swap" s=${15}/>สลับ</span>`:null}</button>`}

function App(){const [session,setSession]=useState(undefined);const [view,setView]=useState(null);const [stack,setStack]=useState([]);const [toast,setToast]=useState(null);const [zoom,setZoom]=useState(null);const [pop,setPop]=useState(false);const [err,setErr]=useState('');
  const [pre,setPre]=useState(lsGet('ss.who')?'login':'landing');const [who,setWho]=useState(lsGet('ss.who')||'contractor');const [gate,setGate]=useState(null);useStore();
  const stackRef=useRef(stack);stackRef.current=stack;
  UI.open=(el,title)=>{history.pushState({ss:'sheet'},'');setStack(s=>[...s,{k:uid(),el,title}])};
  UI.close=()=>{if(stackRef.current.length)history.back()};
  UI.replace=(el,title)=>setStack(s=>[...s.slice(0,-1),{k:uid(),el,title}]);
  UI.zoom=setZoom;UI.toast=m=>{setToast(m);clearTimeout(UI._t);UI._t=setTimeout(()=>setToast(null),3800)};
  UI.go=v=>{setStack([]);if(v!==homeView())history.pushState({ss:'view'},'');setView(v);window.scrollTo(0,0)};
  UI.pickCo=()=>setGate('co');
  const homeView=()=>ME&&isSCG()?'board':'today';
  useEffect(()=>{const onPop=()=>{if(stackRef.current.length)setStack(s=>s.slice(0,-1));else setView(v=>v===homeView()?v:homeView())};window.addEventListener('popstate',onPop);return()=>window.removeEventListener('popstate',onPop)},[]);
  useEffect(()=>{sb.auth.getSession().then(({data})=>setSession(data.session));const {data}=sb.auth.onAuthStateChange((_e,s)=>setSession(s));return()=>data.subscription.unsubscribe()},[]);
  useEffect(()=>{if(!session){ME=null;S.ready=false;S.co=null;return}(async()=>{try{const {data,error}=await sb.from('profiles').select('*').eq('id',session.user.id).single();if(error)throw error;ME=data;
    if(ME.role!=='pending'&&ME.active){await loadAll();startRealtime();
      const cos=myCos();const saved=lsGet('ss.co.'+ME.id);S.co=saved&&(saved==='all'&&isContractor()&&cos.length>1||cos.includes(saved))?saved:cos.length===1?cos[0]:null;
      const pv=(sett('pdpa',null)||{}).version;setGate(ME.pdpa_version!==pv&&pv?'pdpa':!lsGet('ss.installed')&&!matchMedia('(display-mode: standalone)').matches&&/Mobi/.test(navigator.userAgent)?'install':!S.co?'co':null)}
    setView(v=>v||homeView());emit()}catch(e){setErr(errMsg(e))}})()},[session&&session.user.id]);
  const hash=location.hash;if(hash.startsWith('#pass-'))return html`<${PublicPass} token=${hash.slice(6)}/>`;
  if(!CFG.SUPABASE_URL||CFG.SUPABASE_URL.includes('YOUR'))return html`<div className="auth"><div className="auth-card card pad"><h2>ยังไม่ได้ตั้งค่า</h2><p className="sm">แก้ไฟล์ config.js ใส่ SUPABASE_URL และ SUPABASE_ANON_KEY ตามคู่มือ SETUP.md</p></div></div>`;
  if(session===undefined)return html`<div className="auth"><div className="muted">กำลังโหลด…</div></div>`;
  if(!session){if(pre==='landing')return html`<${Landing} go=${w=>{if(w==='help'||w==='privacy')return setPre(w);setWho(w);lsSet('ss.who',w);setPre('login')}}/>`;
    if(pre==='help'||pre==='privacy')return html`<div className="auth"><div className="auth-card col"><button className="btn ghost small" style=${{justifySelf:'start'}} onClick=${()=>setPre('landing')}><${Ic} n="back"/>กลับ</button>${pre==='help'?html`<${Help}/>`:html`<div className="card pad"><${PrivacyText}/></div>`}</div></div>`;
    return html`<${Login} who=${who} back=${()=>{lsSet('ss.who',null);setPre('landing')}}/>`}
  if(err)return html`<div className="auth"><div className="auth-card card pad col"><h2>เกิดข้อผิดพลาด</h2><div className="sm">${err}</div><${Btn} onClick=${()=>sb.auth.signOut()}>ออกจากระบบ</${Btn}></div></div>`;
  if(!ME||(!S.ready&&ME.role!=='pending'&&ME.active))return html`<div className="auth"><div className="muted">กำลังโหลดข้อมูล…</div></div>`;
  if(ME.role==='pending'||!ME.active)return html`<div className="auth"><div className="auth-card card pad col"><h2>บัญชียังไม่ได้รับสิทธิ์</h2><p className="sm">อีเมล ${ME.email} ยังไม่ได้รับเชิญ หรือถูกปิดการใช้งาน ติดต่อผู้ดูแลบริษัทของคุณ หรือ SCG Safety ให้บันทึกคำเชิญ แล้วเข้าสู่ระบบใหม่</p><${Btn} onClick=${()=>sb.auth.signOut()}>ออกจากระบบ</${Btn}></div></div>`;
  if(gate==='pdpa')return html`<${Pdpa} p=${sett('pdpa',null)} done=${async()=>{await loadAll();setGate(/Mobi/.test(navigator.userAgent)&&!lsGet('ss.installed')?'install':!S.co?'co':null)}}/>`;
  if(gate==='install')return html`<${InstallHint} done=${()=>{lsSet('ss.installed',1);setGate(!S.co?'co':null)}}/>`;
  if(gate==='co'||!S.co)return html`<${CompanyPicker} pick=${c=>{S.co=c;lsSet('ss.co.'+ME.id,c);setGate(null);setStack([]);emit()}}/>`;
  const nav=navFor();const fab=()=>{const js=visJobs().filter(x=>isToday(x)&&permitOf(x.id)?.status==='approved'&&!['stopped','done','cancelled'].includes(x.status));const j=js.find(x=>!ciOf(x.id))||js.find(x=>ciOf(x.id)&&!closeOf(ciOf(x.id).id));
    if(!j)return UI.toast('วันนี้ไม่มีงานที่พร้อม check-in');const ci=ciOf(j.id);UI.open(ci?(ci.stage==='setup'?html`<${PassSheet} token=${ci.pass_token}/>`:html`<${CloseoutSheet} cid=${ci.id}/>`):html`<${CheckinSheet} id=${j.id}/>`,ci?'บัตรผ่าน':'Safety Check-in')};
  const un=S.notifs.filter(n=>n.need_ack&&!n.ack_at).length;const V=VIEW[view]||(()=>null);
  const mob=nav.length>5?[...nav.slice(0,4),['more','เพิ่มเติม','more']]:nav;const crumbs=[TITLES[homeView()],...(view!==homeView()?[TITLES[view]]:[]),...stack.map(s=>s.title).filter(Boolean)];
  return html`<div className="app">
    <aside className="side"><button className="logo" onClick=${()=>UI.go(homeView())} aria-label="กลับหน้าหลัก"><div className="logo-mark"><${Ic} n="shield"/></div><div><b>SafeStart</b><span>${isSCG()?ROLE_NAME[ME.role]:ctrName(ME.contractor_id)}</span></div></button>
      <nav className="nav" aria-label="เมนูหลัก">${nav.map(([id,l,ic])=>id==='fab'?html`<button key=${id} className="btn primary block" style=${{margin:'6px 0'}} onClick=${fab}><${Ic} n="check"/>Check-in / บัตรผ่าน / ปิดงาน</button>`:html`<button key=${id} className=${view===id?'on':''} aria-current=${view===id?'page':undefined} title=${l} onClick=${()=>UI.go(id)}><${Ic} n=${ic}/><span>${l}</span>${(id==='todo'||id==='inbox')&&un?html`<span className="cnt">${un}</span>`:null}</button>`)}</nav>
      <div className="side-foot xs">${ME.full_name||ME.email}</div></aside>
    <main className="main"><header className="topbar">${view!==homeView()||stack.length?html`<button className="iconbtn" aria-label="ย้อนกลับ" onClick=${()=>history.back()}><${Ic} n="back"/></button>`:html`<button className="iconbtn logo-sm" aria-label="หน้าหลัก" onClick=${()=>UI.go(homeView())}><${Ic} n="shield"/></button>`}
        <div className="title">${crumbs.length>1?html`<nav className="crumb" aria-label="ตำแหน่ง">${crumbs.map((c,i)=>html`<${Fragment} key=${i}>${i?html`<span className="sep">›</span>`:null}<button className=${i===crumbs.length-1?'cur':''} onClick=${()=>{if(i===0)UI.go(homeView());else if(i===1&&view!==homeView()){const n=stack.length;if(n)history.go(-n)}else{const n=crumbs.length-1-i;if(n>0)history.go(-n)}}}>${c}</button></${Fragment}>`)}</nav>`:null}<h1>${TITLES[view]||''}</h1></div>
        ${isContractor()?html`<${HoldButton} className="sos" label="SOS ฉุกเฉิน กดค้าง 1 วินาที" onHold=${fireSOS}><${Ic} n="sos"/><span>SOS</span></${HoldButton}>`:null}
        <button className="iconbtn" aria-label=${'การแจ้งเตือน '+un} onClick=${()=>setPop(p=>!p)}><${Ic} n="bell"/>${un?html`<span className="dotn">${un>99?'99+':un}</span>`:null}</button></header>
      <${CompanyBand}/>
      ${pop?html`<${NotifPanel} onClose=${()=>setPop(false)}/>`:null}
      <div className="page"><${V}/></div></main>
    <nav className="bnav" aria-label="เมนูหลัก">${mob.map(([id,l,ic])=>id==='fab'?html`<button key=${id} className="fab" onClick=${fab}><span className="ic"><${Ic} n=${ic}/></span><span>${l}</span></button>`
      :html`<button key=${id} className=${view===id?'on':''} onClick=${()=>id==='more'?UI.open(html`<${Sheet} title="เมนู">${nav.slice(4).map(([i2,l2,ic2])=>html`<button key=${i2} className="li" onClick=${()=>UI.go(i2)}><span className="ic-circle mute"><${Ic} n=${ic2}/></span><span className="grow t">${l2}</span><${Ic} n="chev"/></button>`)}</${Sheet}>`,'เมนู'):UI.go(id)}><${Ic} n=${ic}/><span>${l}</span>${(id==='todo'||id==='inbox')&&un?html`<span className="cnt">${un}</span>`:null}</button>`)}</nav>
    ${stack.map(s=>html`<${Fragment} key=${s.k}>${s.el}</${Fragment}>`)}
    ${zoom?html`<div className="lightbox" onClick=${()=>setZoom(null)}><img src=${zoom} alt="รูปขยาย"/></div>`:null}
    ${toast?html`<div className="toast" role="status">${toast}</div>`:null}</div>`}

(function(){const t=lsGet('ss.theme');if(t)document.documentElement.dataset.theme=t;const f=lsGet('ss.fs');if(f)document.body.style.fontSize=f+'px';
  if('serviceWorker' in navigator&&location.protocol==='https:'&&!window.SAFESTART_DEMO)navigator.serviceWorker.register('sw.js').catch(()=>{})})();
