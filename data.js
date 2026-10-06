/* SafeStart · ข้อมูลและกติกาฝั่งหน้าเว็บ (data.js) */
const CFG=window.SAFESTART_CONFIG||{};
const sb=supabase.createClient(CFG.SUPABASE_URL,CFG.SUPABASE_ANON_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
let ME=null;
const S={ready:false,co:null,settingsRows:[],companies:[],groups:[],projects:[],jobTypes:[],contractors:[],links:[],docs:[],profiles:[],invites:[],
  workers:[],wlinks:[],certs:[],creviews:[],flags:[],teams:[],teamMembers:[],jobs:[],permits:[],checkins:[],closeouts:[],findings:[],incidents:[],notifs:[],health:[],selfdec:[]};
const subs=new Set();const emit=()=>subs.forEach(f=>f());
function useStore(){const [,f]=useState(0);useEffect(()=>{const g2=()=>f(x=>x+1);subs.add(g2);return()=>subs.delete(g2)},[]);return S}

const ROLE_NAME={pending:'รอสิทธิ์',team_lead:'หัวหน้าทีมช่าง',contractor_admin:'ผู้ดูแลบริษัทผู้รับเหมา',installation_consultant:'Installation Consultant (IC)',
  purchasing:'Purchasing',ic_qc_manager:'IC & QC Manager',ms_manager:'Merchandise & Sourcing Manager',ms_director:'Merchandise & Sourcing Director',safety_admin:'SCG Safety (Admin)',executive:'ผู้บริหาร'};
const SCG_ROLES=['installation_consultant','purchasing','ic_qc_manager','ms_manager','ms_director','safety_admin','executive'];
const isSCG=()=>ME&&SCG_ROLES.includes(ME.role);
const isContractor=()=>ME&&['team_lead','contractor_admin'].includes(ME.role);
const isCAdmin=()=>ME&&ME.role==='contractor_admin';
const isSafety=()=>ME&&ME.role==='safety_admin';
const canApproveWorkers=()=>ME&&['purchasing','installation_consultant','safety_admin'].includes(ME.role);
const canStop=()=>ME&&['installation_consultant','ic_qc_manager','safety_admin','ms_manager','ms_director'].includes(ME.role);
const canImport=()=>ME&&['purchasing','safety_admin','ic_qc_manager','installation_consultant'].includes(ME.role);
const canScan=()=>ME&&['installation_consultant','ic_qc_manager','safety_admin','ms_manager','ms_director'].includes(ME.role);

async function q(table,build){let x=sb.from(table).select('*');if(build)x=build(x);const {data,error}=await x;if(error)throw error;return data||[]}
async function qs(table,build){try{return await q(table,build)}catch(e){console.warn(table,e);return []}}
async function rpc(fn,args){const {data,error}=await sb.rpc(fn,args||{});if(error)throw error;return data}

let loading=null;
async function loadAll(){if(loading)return loading;loading=(async()=>{
  const from=addDays(today(),-45);
  const [st,cos,grp,projs,jts,ctrs,links,docs,profs,inv,wks,wl,certs,crv,flags,teams,tms,jobs,pms,cis,cls,fds,inc,nts,hc,sd]=await Promise.all([
    q('settings'),qs('scg_companies',x=>x.order('name')),qs('install_groups',x=>x.order('sort')),qs('projects',x=>x.order('name')),qs('job_types',x=>x.order('name')),
    qs('contractors',x=>x.order('name')),qs('contractor_links'),qs('contractor_docs'),qs('profiles'),qs('invites'),
    qs('workers',x=>x.order('full_name')),qs('worker_links'),qs('worker_certs'),qs('cert_reviews'),qs('lsr_flags'),qs('teams',x=>x.order('name')),qs('team_members'),
    qs('jobs',x=>x.gte('end_date',from).order('start_date')),qs('permits'),qs('checkins',x=>x.gte('work_date',from)),qs('closeouts',x=>x.gte('created_at',from)),
    qs('findings',x=>x.gte('created_at',addDays(today(),-90)).order('created_at',{ascending:false})),qs('incidents',x=>x.gte('created_at',from).order('created_at',{ascending:false})),
    qs('notifications',x=>x.eq('to_id',ME.id).order('created_at',{ascending:false}).limit(150)),qs('health_checks',x=>x.gte('work_date',addDays(today(),-7))),qs('selfdec_answers')]);
  Object.assign(S,{settingsRows:st,companies:cos,groups:grp,projects:projs,jobTypes:jts,contractors:ctrs,links,docs,profiles:profs,invites:inv,workers:wks,wlinks:wl,certs,creviews:crv,flags,
    teams,teamMembers:tms,jobs,permits:pms,checkins:cis,closeouts:cls,findings:fds,incidents:inc,notifs:nts,health:hc,selfdec:sd,ready:true,loadedAt:Date.now()});
  const me=profs.find(p=>p.id===ME.id);if(me)ME=me;
  emit()})();try{await loading}finally{loading=null}}
let rt=null,rtTimer=null;
function startRealtime(){if(rt)return;const kick=()=>{clearTimeout(rtTimer);rtTimer=setTimeout(()=>loadAll().catch(()=>{}),700)};
  rt=sb.channel('safestart');['jobs','permits','checkins','closeouts','findings','notifications','worker_links','incidents'].forEach(t=>rt.on('postgres_changes',{event:'*',schema:'public',table:t},kick));
  rt.subscribe();setInterval(()=>{if(document.visibilityState==='visible')loadAll().catch(()=>{})},90000)}
async function act(fn,ok){const r=await run(fn,ok);if(r!==false)await loadAll().catch(()=>{});return r}

/* ---------- ค่าตั้งค่า: ค่ากลาง + ค่าของบริษัท ---------- */
function sett(k,co){co=co===undefined?(S.co==='all'?null:S.co):co;const own=co&&S.settingsRows.find(r=>r.scg_company_id===co&&r.key===k);
  const base=S.settingsRows.find(r=>!r.scg_company_id&&r.key===k);return(own||base||{}).value}

/* ---------- ค้นหา ---------- */
const byId=(arr,id)=>arr.find(x=>x.id===id);
const coOf=id=>byId(S.companies,id);
const coName=id=>coOf(id)?.name||'–';
const coShort=id=>coOf(id)?.short||coOf(id)?.name||'–';
const coColor=id=>coOf(id)?.color||'#5C6B7F';
const ctrOf=id=>byId(S.contractors,id);
const ctrName=id=>ctrOf(id)?.name||'–';
const projOf=id=>byId(S.projects,id);
const grpName=id=>byId(S.groups,id)?.name||'–';
const profOf=id=>byId(S.profiles,id);
const profName=id=>{const p=profOf(id);return p?(p.full_name||p.email):'–'};
const workerOf=id=>byId(S.workers,id);
const workerName=id=>workerOf(id)?.full_name||'–';
const jtNames=j=>(j.job_type_ids||[]).map(id=>byId(S.jobTypes,id)?.name).filter(Boolean).join(', ')||'–';
const hzName=h=>(sett('hazard_names',null)||{})[h]||h;
const certName=c=>(sett('cert_types',null)||{})[c]||c;
const permitOf=jid=>S.permits.find(p=>p.job_id===jid);
const ciOf=(jid,d)=>S.checkins.find(c=>c.job_id===jid&&c.work_date===(d||today())&&!c.voided);
const closeOf=cid=>S.closeouts.find(c=>c.checkin_id===cid);
const teamOf=id=>byId(S.teams,id);
const teamWorkers=tid=>S.teamMembers.filter(m=>m.team_id===tid).map(m=>m.worker_id);
const jobFindings=jid=>S.findings.filter(f=>f.job_id===jid);
const isToday=j=>today()>=j.start_date&&today()<=j.end_date;
const dayNo=j=>Math.round((new Date(today())-new Date(j.start_date))/864e5)+1;
const totalDays=j=>Math.round((new Date(j.end_date)-new Date(j.start_date))/864e5)+1;
const RISK={high:['stop','เสี่ยงสูง'],med:['warn','เสี่ยงกลาง'],low:['go','เสี่ยงต่ำ']};
const nowMin=()=>{const d=new Date();return d.getHours()*60+d.getMinutes()};
const tMin=t=>{const [h,m]=(t||'08:00').split(':').map(Number);return h*60+(m||0)};
const inCo=x=>!S.co||S.co==='all'||x===S.co;
const myCos=()=>isSCG()?(ME.scg_company_ids||[]):S.links.filter(l=>l.contractor_id===ME.contractor_id).map(l=>l.scg_company_id);
const visJobs=()=>S.jobs.filter(j=>inCo(j.scg_company_id));
const linkOf=(wid,co)=>S.wlinks.find(l=>l.worker_id===wid&&l.scg_company_id===co);
const ctrLink=(cid,co)=>S.links.find(l=>l.contractor_id===cid&&l.scg_company_id===co);
const isICof=p=>p&&[p.ic_id,p.backup_ic_id].includes(ME.id);
const canApproveJob=j=>{const p=projOf(j.project_id);return isSCG()&&myCos().includes(j.scg_company_id)&&(isICof(p)||['ic_qc_manager','safety_admin'].includes(ME.role))};

/* สถานะงานวันนี้ → [สี, ข้อความ, ลำดับความสำคัญ] */
function jobState(j){
  if(j.status==='stopped')return['stop','หยุดงาน',0];
  if(j.status==='cancelled')return['mute','ยกเลิก',9];
  const pm=permitOf(j.id);
  if(j.status==='done')return['info','ปิดงานจบ',8];
  if(!pm)return['mute','ยังไม่ยื่นแผน',3];
  if(pm.status==='pending')return['warn','รออนุมัติ',2];
  if(pm.status==='rejected')return['stop','ถูกตีกลับ',1];
  if(!isToday(j))return['mute',today()<j.start_date?'รอวันเริ่ม':'เลยกำหนด',7];
  const ci=ciOf(j.id);
  if(!ci){const late=nowMin()>tMin(j.start_time)+((sett('rules',j.scg_company_id)||{}).late_min||30);return late?['warn','ยังไม่ check-in',1]:['mute','รอ check-in',4]}
  if(closeOf(ci.id))return['info','ปิดงานวันนี้แล้ว',6];
  if(ci.stage==='setup')return new Date(ci.setup_due)<new Date()?['stop','บัตรส้มเกินเวลา',1]:['warn','บัตรส้ม · ติดจุดยึด',2];
  const open=jobFindings(j.id).some(f=>f.status==='open');
  return open||ci.late?['warn',open?'มีข้อบกพร่อง':'check-in สาย',3]:['go','กำลังทำงาน',5];
}
const StateChip=({j})=>{const s=jobState(j);return html`<${Chip} c=${s[0]} t=${s[1]} dot=${true}/>`};
const HzIcons=({h,size})=>html`<span className="hzs">${HZ_ORDER.filter(x=>(h||[]).includes(x)).map(x=>html`<span key=${x} className="hz" title=${hzName(x)}><${Ic} n=${x} s=${size||15}/>${hzName(x)}</span>`)}</span>`;
const CoBadge=({id})=>html`<span className="cobadge" style=${{'--co':coColor(id)}}>${coShort(id)}</span>`;

/* ช่างคนนี้เข้างานของบริษัท co ได้ไหม (ฐานข้อมูลตรวจซ้ำอีกชั้น) */
function workerBlockers(w,co,hazards,on,wah){
  const out=[];on=on||today();if(!w)return['ไม่พบช่าง'];const l=linkOf(w.id,co);
  if(!l)out.push('ยังไม่ได้ขอเข้าทำงานกับ '+coShort(co));else if(l.status==='pending')out.push('รออนุมัติ');else if(l.status==='rejected')out.push('ไม่ได้รับอนุมัติ');
  if(!w.active)out.push('ปิดใช้งาน');
  if(!w.id_verified_at)out.push('ยังไม่ตรวจตัวบุคคล');
  if(l&&l.banned_forever)out.push('ห้ามทำงานตลอดชีพ (LSR)');else if(l&&l.banned_until&&l.banned_until>=on)out.push('ห้ามทำงานถึง '+thD(l.banned_until)+' (LSR)');
  if(w.foreign_worker&&(!w.work_permit_expiry||w.work_permit_expiry<on))out.push('Work permit หมดอายุ');
  if((sett('rules',co)||{}).enforce_certs!==false){const hc=sett('hazard_certs',co)||{};
    const req=[...new Set([...(hc.all||[]),...(hazards||[]).filter(h=>h!=='wah'||wah).flatMap(h=>hc[h]||[])])];
    req.forEach(c=>{if(!S.certs.some(x=>x.worker_id===w.id&&x.cert_type===c&&(!x.expires_on||x.expires_on>=on)&&S.creviews.some(r=>r.cert_id===x.id&&r.scg_company_id===co&&r.status==='approved')))out.push('ขาด '+certName(c))})}
  if(wah){if(!w.birth_date)out.push('ไม่มีวันเกิด');else if((new Date(on)-new Date(w.birth_date))/31557600000<18)out.push('อายุต่ำกว่า 18');
    if(!['ok','doctor_ok'].includes(w.selfdec_status)||!w.selfdec_until||w.selfdec_until<on)out.push(['need_doctor','doctor_submitted'].includes(w.selfdec_status)?'รอใบรับรองแพทย์':'Self-declaration หมดอายุ/ยังไม่ทำ')}
  return out;
}
const SELFDEC={none:['mute','ยังไม่ทำ'],ok:['go','ผ่าน'],need_doctor:['stop','ต้องมีใบแพทย์'],doctor_submitted:['warn','รอ Safety รับรอง'],doctor_ok:['go','ผ่าน (มีใบแพทย์)']};

/* หมวดเช็กลิสต์ที่ใช้กับงานนี้ */
function jobSections(j,wahOn){const a=j.site_answers||{};let s=['all',...(j.hazards||[])];if(j.occupied)s.push('occupied');if(a.ladder)s.push('ladder');if(a.scaffold)s.push('scaffold');
  if(wahOn===false)s=s.filter(x=>!['wah','ladder','scaffold'].includes(x));return s}
const checklistFor=(j,wahOn)=>{const s=jobSections(j,wahOn);return(sett('checklist',j.scg_company_id)||[]).filter(x=>s.includes(x.when))};
const setupItems=j=>checklistFor(j,true).flatMap(s=>s.items.filter(i=>i.setup));
function riskPreview(j,a){const h=new Set();(j.job_type_ids||[]).forEach(id=>(byId(S.jobTypes,id)?.hazards||[]).forEach(x=>h.add(x)));
  ['height18:wah','hot:hot','electric:electric','confined:confined','lifting:lifting','excavation:excavation','chemical:chemical'].forEach(p=>{const [k,v]=p.split(':');if(a[k])h.add(v)});
  const hz=HZ_ORDER.filter(x=>h.has(x));return{hazards:hz,risk:hz.some(x=>['wah','electric','hot','confined'].includes(x))?'high':hz.some(x=>['lifting','excavation','chemical'].includes(x))?'med':'low'}}

/* ---------- พยากรณ์อากาศ (Open-Meteo ฟรี ไม่ต้องสมัคร) ---------- */
const WX={};
function heatIndex(t,rh){const f=t*9/5+32;if(f<80)return t;const hi=-42.379+2.04901523*f+10.14333127*rh-.22475541*f*rh-.00683783*f*f-.05481717*rh*rh+.00122874*f*f*rh+.00085282*f*rh*rh-.00000199*f*f*rh*rh;return Math.round((hi-32)*5/9)}
async function fetchWeather(pts){const key=p=>p.map(x=>x.toFixed(2)).join(',');const need=pts.filter(p=>!WX[key(p)]);
  if(need.length){try{const u='https://api.open-meteo.com/v1/forecast?latitude='+need.map(p=>p[0].toFixed(3)).join(',')+'&longitude='+need.map(p=>p[1].toFixed(3)).join(',')+
      '&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,wind_gusts_10m,weather_code&timezone=Asia%2FBangkok&forecast_days=2';
    const r=await fetch(u);const d=await r.json();const arr=Array.isArray(d)?d:[d];arr.forEach((x,i)=>{WX[key(need[i])]=x.hourly})}catch(e){need.forEach(p=>WX[key(p)]=null)}}
  return pts.map(p=>WX[key(p)])}
/* ประเมินระดับในช่วงเวลาทำงาน → {level: ok|watch|warn|stop, text, peak} */
function evalWeather(h,co,from,to,date){if(!h)return null;const th=sett('weather',co)||{gust:[25,40,55],rain_prob:[40,70],heat:[27,33,42,52]};date=date||today();
  const f=tMin(from||th.work_from||'08:00')/60,t=tMin(to||th.work_to||'17:00')/60;let lv=0,why=[],peak={gust:0,rain:0,hi:0,thunder:null,rainNow:null};
  h.time.forEach((ts,i)=>{if(!ts.startsWith(date))return;const hr=+ts.slice(11,13);if(hr<f||hr>t)return;
    const gst=h.wind_gusts_10m[i]||0,rp=h.precipitation_probability[i]||0,hi=heatIndex(h.temperature_2m[i],h.relative_humidity_2m[i]),wc=h.weather_code[i];
    peak.gust=Math.max(peak.gust,gst);peak.rain=Math.max(peak.rain,rp);peak.hi=Math.max(peak.hi,hi);if(wc>=95&&peak.thunder==null)peak.thunder=hr;
    if((h.precipitation[i]||0)>=.5&&peak.rainNow==null)peak.rainNow=hr});
  const G=th.gust,R=th.rain_prob,H=th.heat;
  if(peak.gust>=G[2]){lv=3;why.push('ลมกระโชก '+Math.round(peak.gust)+' กม./ชม. หยุดงานบนที่สูง')}else if(peak.gust>=G[1]){lv=Math.max(lv,2);why.push('ลมกระโชก '+Math.round(peak.gust)+' กม./ชม. งดยกแผ่นใหญ่')}else if(peak.gust>=G[0]){lv=Math.max(lv,1);why.push('ลม '+Math.round(peak.gust)+' กม./ชม. มัดยึดวัสดุ')}
  if(peak.thunder!=null){lv=Math.max(lv,2);why.push('พายุฝนฟ้าคะนองราว '+z(peak.thunder)+':00 วางแผนลงก่อน (กฎ 30/30)')}
  if(peak.rain>=R[1]){lv=Math.max(lv,2);why.push('โอกาสฝน '+peak.rain+'%')}else if(peak.rain>=R[0]){lv=Math.max(lv,1);why.push('โอกาสฝน '+peak.rain+'%')}
  if(peak.hi>=H[3]){lv=3;why.push('ดัชนีความร้อน '+peak.hi+'°C อันตรายมาก')}else if(peak.hi>=H[2]){lv=Math.max(lv,2);why.push('ดัชนีความร้อน '+peak.hi+'°C ทำต่อเนื่อง ≤ 60 นาที พัก 15')}else if(peak.hi>=H[1]){lv=Math.max(lv,1);why.push('ดัชนีความร้อน '+peak.hi+'°C จัดเวลาพัก ดื่มน้ำ')}
  return{level:['ok','watch','warn','stop'][lv],text:why.join(' · ')||'อากาศปกติในช่วงทำงาน',peak}}
const WXL={ok:['go','sun','อากาศปกติ'],watch:['info','cloud','เฝ้าระวัง'],warn:['warn','storm','ระวังสูง'],stop:['stop','storm','หยุดงานบนที่สูง']};
function useWeather(jobs){const [w,setW]=useState({});const k=jobs.map(j=>j.id).join();
  useEffect(()=>{let a=true;const js=jobs.filter(j=>j.lat!=null);if(!js.length)return;fetchWeather(js.map(j=>[j.lat,j.lng])).then(hs=>{if(!a)return;const o={};
    js.forEach((j,i)=>{o[j.id]=evalWeather(hs[i],j.scg_company_id,String(j.start_time).slice(0,5),null,isToday(j)?today():j.start_date)});setW(o)})
    return()=>{a=false}},[k]);return w}
const WxChip=({w})=>w?html`<${Chip} c=${WXL[w.level][0]} icon=${WXL[w.level][1]} t=${WXL[w.level][2]}/>`:null;
