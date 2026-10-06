/* SafeStart · หน้าจอฝั่งผู้รับเหมา (views_c.js) */

function TeamDots({j}){const ws=teamWorkers(j.team_id).map(workerOf).filter(Boolean);if(!ws.length)return null;
  const wah=(j.hazards||[]).includes('wah');const st=ws.map(w=>workerBlockers(w,j.scg_company_id,j.hazards,isToday(j)?today():j.start_date,wah));const ok=st.filter(b=>!b.length).length;
  return html`<div className="avs">${ws.slice(0,6).map((w,i)=>html`<span key=${w.id} title=${w.full_name+(st[i].length?' · '+st[i].join(', '):' · พร้อม')}><${Avatar} n=${w.nickname||w.full_name} dot=${st[i].length?'bad':'ok'}/></span>`)}
    <span className="xs muted">พร้อม ${ok}/${ws.length}</span></div>`}

function JobCard({j,w,compact}){const p=projOf(j.project_id);const pm=permitOf(j.id);const acts=jobActions(j);
  return html`<div className="job-card click" role="button" tabIndex="0" onClick=${()=>UI.open(html`<${JobSheet} id=${j.id}/>`,jtNames(j))} onKeyDown=${e=>e.key==='Enter'&&e.currentTarget.click()}>
    <div className="between"><div className="row" style=${{gap:6}}><${CoBadge} id=${j.scg_company_id}/><${Chip} c=${RISK[j.risk][0]} t=${RISK[j.risk][1]}/>${w&&w.level!=='ok'&&(j.hazards||[]).includes('wah')?html`<${WxChip} w=${w}/>`:null}</div><${StateChip} j=${j}/></div>
    <div><h3>${jtNames(j)} · ${j.house_no||'–'}</h3><div className="sm muted">${p?.name||''} · PO <span className="num">${j.po_no}</span>${isToday(j)?' · วันที่ '+dayNo(j)+'/'+totalDays(j):' · '+thDS(j.start_date)+'–'+thDS(j.end_date)} · นัด ${String(j.start_time).slice(0,5)}</div></div>
    <${HzIcons} h=${j.hazards}/>
    ${compact?null:html`<${TeamDots} j=${j}/>`}
    ${pm?.status==='rejected'?html`<div className="sm" style=${{color:'var(--stop)'}}>ตีกลับ: ${pm.note}</div>`:null}
    ${j.status==='stopped'?html`<div className="sm" style=${{color:'var(--stop)'}}>${j.stop_reason}</div>`:null}
    ${acts.length?html`<div className="row" onClick=${e=>e.stopPropagation()}>${acts}</div>`:null}
  </div>`}

function jobActions(j){if(!isContractor())return[];const ci=ciOf(j.id);const pm=permitOf(j.id);const out=[];
  if(isCAdmin()&&['planned','permit_pending','approved'].includes(j.status)&&!S.checkins.some(c=>c.job_id===j.id&&!c.voided))
    out.push(html`<${Btn} key="p" kind=${!pm||pm.status==='rejected'?'primary':''} icon="flag" onClick=${()=>UI.open(html`<${PlanSheet} id=${j.id}/>`,'ยื่นแผนงาน')}>${pm?'แก้แผน/ยื่นใหม่':'ยื่นแผนงาน'}</${Btn}>`);
  if(isToday(j)&&pm?.status==='approved'&&!['stopped','done','cancelled'].includes(j.status)){
    if(!ci)out.push(html`<${Btn} key="c" kind="primary" big=${true} block=${true} icon="check" onClick=${()=>UI.open(html`<${CheckinSheet} id=${j.id}/>`,'Safety Check-in')}>เริ่ม Safety Check-in</${Btn}>`);
    else if(!closeOf(ci.id))out.push(html`<${Btn} key="pass" kind=${ci.stage==='setup'?'orange':'go'} icon="qr" onClick=${()=>UI.open(html`<${PassSheet} token=${ci.pass_token}/>`,'บัตรผ่าน')}>${ci.stage==='setup'?'บัตรส้ม · ส่งรูปจุดยึด':'บัตรผ่านวันนี้'}</${Btn}>`,
      html`<${Btn} key="close" kind="dark" icon="ok" onClick=${()=>UI.open(html`<${CloseoutSheet} cid=${ci.id}/>`,'ปิดงาน')}>ปิดงานประจำวัน</${Btn}>`);
  }
  const nav=p_nav(j);if(nav)out.push(html`<a key="nav" className="btn" href=${nav} target="_blank" rel="noopener"><${Ic} n="map"/>นำทาง</a>`);
  return out}
const p_nav=j=>j.lat?`https://www.google.com/maps/dir/?api=1&destination=${j.lat},${j.lng}`:j.address?`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(j.address)}`:null;

/* ---------- หน้าหลักผู้รับเหมา ---------- */
function CToday(){useStore();const js=visJobs().filter(j=>isToday(j)&&!['cancelled','done'].includes(j.status));const w=useWeather(js);
  const tom=visJobs().filter(j=>j.start_date<=addDays(today(),1)&&j.end_date>=addDays(today(),1)&&j.status!=='cancelled');
  const un=S.notifs.filter(n=>n.need_ack&&!n.ack_at&&inCo(n.scg_company_id||S.co));const open=S.findings.filter(f=>f.status==='open'&&inCo(f.scg_company_id));
  const worst=js.map(j=>w[j.id]).filter(Boolean).sort((a,b)=>['ok','watch','warn','stop'].indexOf(b.level)-['ok','watch','warn','stop'].indexOf(a.level))[0];
  return html`<div className="col">
    <div className="hello"><${BgArt} k="house"/><div className="eyebrow">${thDL(today())}</div><h2>สวัสดี ${ME.full_name||''}</h2><div className="sm muted">${ctrName(ME.contractor_id)} · ${ROLE_NAME[ME.role]}</div></div>
    ${worst&&worst.level!=='ok'?html`<div className=${'wx '+worst.level}><span className="ic-circle"><${Ic} n=${WXL[worst.level][1]}/></span><div className="grow"><b>${WXL[worst.level][2]}</b><div className="sm">${worst.text}</div></div></div>`:null}
    ${js.length?html`<div className="g2">${js.map(j=>html`<${JobCard} key=${j.id} j=${j} w=${w[j.id]}/>`)}</div>`:html`<${Card} pad=${true}><${Empty} icon="cal" t="วันนี้ไม่มีงาน" sub="งานที่ SCG มอบให้บริษัทจะแสดงที่นี่"/></${Card}>`}
    <div className="g2">
    <${Card}><${CardH} icon="warn" title="ค้างต้องทำ" right=${html`<${Chip} c=${un.length+open.length?'stop':'go'} t=${(un.length+open.length)+' เรื่อง'}/>`}/>
      <div className="card-b col tight">${un.length+open.length===0?html`<div className="sm muted">ไม่มีเรื่องค้าง</div>`:null}
        ${un.slice(0,5).map(n=>html`<${NotifRow} key=${n.id} n=${n}/>`)}
        ${open.slice(0,5).map(f=>html`<${FindingRow} key=${f.id} f=${f}/>`)}
      </div></${Card}>
    <${Card}><${CardH} icon="cal" title="พรุ่งนี้"/><div className="card-b col tight">${tom.length?tom.map(j=>{const pm=permitOf(j.id);return html`<button key=${j.id} className="li" onClick=${()=>UI.open(html`<${JobSheet} id=${j.id}/>`,j.po_no)}><div className="grow"><div className="t">${jtNames(j)} · ${j.house_no||'–'}</div><div className="s">${projOf(j.project_id)?.name||''} · ${coShort(j.scg_company_id)}</div></div><${Chip} c=${pm?.status==='approved'?'go':pm?.status==='pending'?'warn':'stop'} t=${pm?.status==='approved'?'อนุมัติแล้ว':pm?.status==='pending'?'รออนุมัติ':pm?.status==='rejected'?'ถูกตีกลับ':'ยังไม่ยื่นแผน'}/></button>`}):html`<div className="sm muted">ไม่มีงาน</div>`}</div></${Card}>
    </div>
  </div>`}

function NotifRow({n}){return html`<div className="between nrow"><div className="grow sm"><b>${n.urgent?html`<span style=${{color:'var(--stop)'}}>ด่วน · </span>`:''}${n.title}</b>${n.body?html`<div className="xs muted">${n.body}</div>`:null}<div className="xs muted">${ago(n.created_at)}</div></div>
  ${n.need_ack&&!n.ack_at?html`<${Btn} small=${true} kind=${n.urgent?'red':'dark'} onClick=${()=>act(()=>rpc('ack',{p_id:n.id}),'รับทราบแล้ว')}>รับทราบ</${Btn}>`:html`<span className="xs muted">${n.ack_at?'รับทราบ '+hm(n.ack_at):''}</span>`}</div>`}

function CJobs(){useStore();const [f,setF]=useState('now');const js=visJobs();
  const list=js.filter(j=>f==='now'?j.end_date>=today()&&!['done','cancelled'].includes(j.status):j.end_date<today()||['done','cancelled'].includes(j.status));
  const w=useWeather(list.filter(j=>j.start_date<=addDays(today(),1)));
  return html`<div className="col"><${Seg} v=${f} set=${setF} opts=${[['now','งานปัจจุบัน/ถัดไป'],['past','ที่ผ่านมา']]}/>
    ${list.length?html`<div className="g2">${list.map(j=>html`<${JobCard} key=${j.id} j=${j} w=${w[j.id]}/>`)}</div>`:html`<${Empty} icon="cal" t="ไม่มีงาน"/>`}</div>`}

/* ---------- ยื่นแผนงาน ---------- */
const PLAN_Q=[['height18','ทำงานสูงตั้งแต่ 1.8 ม. ขึ้นไป (หลังคา รางน้ำ ฝ้าชายคา)','wah'],['ladder','ขึ้นที่สูงด้วยบันได','wah'],['scaffold','ใช้นั่งร้าน','wah'],
  ['confined','เข้าไปทำงานในฝ้า/ใต้หลังคา','confined'],['hot','มีงานเชื่อม ตัด เจียร (ประกายไฟ)','hot'],['electric','ต่อไฟจากตู้/ทำงานกับระบบไฟฟ้า','electric'],
  ['lifting','ยกแผ่นใหญ่/ของหนักขึ้นที่สูง','lifting'],['excavation','ขุดดิน','excavation'],['chemical','ใช้สารเคมี (สี กันซึม กาว ทินเนอร์)','chemical'],['occupied','บ้านมีผู้อยู่อาศัยระหว่างทำงาน','home']];
function PlanSheet({id}){useStore();const j=byId(S.jobs,id);const teams=S.teams.filter(t=>t.contractor_id===j.contractor_id);
  const extra=[...new Set((j.job_type_ids||[]).flatMap(t=>byId(S.jobTypes,t)?.extra||[]))];
  const [team,setTeam]=useState(j.team_id||teams[0]?.id||'');
  const [a,setA]=useState(()=>{const base={occupied:j.occupied};(j.hazards||[]).forEach(h=>{const q2=PLAN_Q.find(x=>x[2]===h&&x[0]!=='ladder'&&x[0]!=='scaffold');if(q2)base[q2[0]]=true});return{...base,...(j.site_answers||{})}});
  const [method,setMethod]=useState(j.setup_method||'');const [sw,setSw]=useState(j.setup_worker_ids||[]);
  const pv=riskPreview(j,a);const set=(k,v)=>setA(o=>({...o,[k]:v}));const wah=pv.hazards.includes('wah');
  const ws=team?teamWorkers(team).map(workerOf).filter(Boolean):[];const methods=sett('setup_methods',j.scg_company_id)||[];
  const err=!team?'เลือกทีม':wah&&!a.anchor?'ตอบเรื่องจุดยึด':wah&&a.anchor==='none'?'ไม่มีจุดยึด = ห้ามทำงานที่สูง ติดต่อ IC':wah&&a.anchor==='install'&&(!method||!sw.length)?'เลือกวิธีติดตั้งและคนขึ้นติดตั้ง':wah&&!a.ladder&&!a.scaffold?'เลือกวิธีขึ้นที่สูง (บันได/นั่งร้าน)':null;
  return html`<${Sheet} title=${'ยื่นแผนงาน · '+j.po_no} sub=${jtNames(j)+' · '+(j.house_no||'–')+' · '+coName(j.scg_company_id)} foot=${html`<div className="col tight" style=${{width:'100%'}}>${err?html`<div className="xs" style=${{color:'var(--warn)'}}>${err}</div>`:null}
      <${Btn} kind="primary" block=${true} disabled=${!!err} onClick=${async()=>{const r=await act(()=>rpc('submit_plan',{p_job:id,p_team:team,p_answers:a,p_setup_method:a.anchor==='install'?method:null,p_setup_workers:a.anchor==='install'?sw:[]}));
        if(r){UI.close();UI.toast(r.status==='approved'?(r.risk==='med'?'อนุมัติแล้ว (เสี่ยงกลาง · แจ้ง IC ให้ทราบ)':'อนุมัติอัตโนมัติ (เสี่ยงต่ำ)'):'ส่งให้ IC อนุมัติแล้ว'+(r.late?' · ยื่นช้ากว่ากำหนด':''))}}}>ยื่นแผนงาน</${Btn}></div>`}>
    <${Field} label="ทีมที่เข้างาน">${teams.length?html`<${Sel} v=${team} set=${setTeam} opts=${[['','เลือกทีม'],...teams.map(t=>[t.id,t.name+' · '+profName(t.lead_id)])]}/>`:html`<${Banner} kind="warn">ยังไม่มีทีม สร้างทีมในเมนู "ทีมและช่าง" ก่อน</${Banner}>`}</${Field}>
    <div className="col tight"><div className="eyebrow">คำถามหน้างาน</div>
      ${PLAN_Q.filter(([k])=>!['ladder','scaffold'].includes(k)||a.height18).map(([k,t,ic])=>html`<div key=${k} className="qrow"><span className="ic-circle mute"><${Ic} n=${ic}/></span><span className="grow">${t}</span><${Seg} v=${a[k]?'y':'n'} set=${v=>set(k,v==='y')} opts=${[['n','ไม่'],['y','ใช่']]}/></div>`)}
      ${extra.includes('asbestos')?html`<div className="qrow"><span className="ic-circle mute"><${Ic} n="warn"/></span><span className="grow">หลังคาเดิมเป็นกระเบื้องลอนเก่า (อาจมีใยหิน)</span><${Seg} v=${a.asbestos?'y':'n'} set=${v=>set('asbestos',v==='y')} opts=${[['n','ไม่'],['y','ใช่']]}/></div>`:null}
      ${a.asbestos?html`<${Banner} kind="warn">อาจมีใยหิน: ห้ามตัด/เจียรแห้ง ฉีดน้ำให้ชื้น ใส่หน้ากาก N95 ขึ้นไป และเก็บเศษใส่ถุงปิด · แจ้ง IC ก่อนเริ่ม</${Banner}>`:null}</div>
    ${wah?html`<${Card} pad=${true} className="col tight"><b>จุดยึด / Lifeline (บังคับทุกงานที่สูง)</b>
      <div className="choices">${[['existing','มีจุดยึดที่แข็งแรงอยู่แล้ว'],['install','ต้องติดตั้งก่อนทำงาน'],['none','ไม่มีจุดยึดที่เหมาะสม']].map(([k,l])=>html`<button key=${k} className=${cx('choice',a.anchor===k&&'on')} onClick=${()=>set('anchor',k)}><span className="t">${l}</span></button>`)}</div>
      ${a.anchor==='none'?html`<${Banner} kind="stop">ห้ามทำงานบนที่สูงของบ้านนี้ ติดต่อ IC ของโครงการเพื่อหาวิธีติดตั้งจุดยึด</${Banner}>`:null}
      ${a.anchor==='install'?html`<${Field} label="วิธีขึ้นไปติดตั้ง (ก่อนมีจุดยึด)"><${Sel} v=${method} set=${setMethod} opts=${[['','เลือกวิธี'],...methods.map(m=>[m,m])]}/></${Field}>
        <div className="sm">คนที่ขึ้นไปติดตั้ง (ได้บัตรส้ม · ส่งรูปภายใน ${(sett('rules',j.scg_company_id)||{}).setup_minutes||60} นาที)</div>
        ${ws.map(w=>html`<${Check} key=${w.id} on=${sw.includes(w.id)} set=${v=>setSw(o=>v?[...o,w.id]:o.filter(x=>x!==w.id))}>${w.full_name} <span className="sm muted">${w.position||''}</span></${Check}>`)}`:null}
    </${Card}>`:null}
    <${Banner} kind=${pv.risk==='high'?'warn':'info'}>ระดับความเสี่ยง: <b>${RISK[pv.risk][1]}</b>${pv.hazards.length?' · '+pv.hazards.map(hzName).join(', '):''} — ${pv.risk==='high'?'IC ของโครงการอนุมัติ (ยื่นก่อน '+((sett('sla',j.scg_company_id)||{}).permit_deadline||'16:00')+' น. ของวันก่อนเข้างาน)':pv.risk==='med'?'คุณอนุมัติได้ทันที ระบบแจ้ง IC ให้ทราบ':'อนุมัติอัตโนมัติ'}</${Banner}>
    ${team?html`<div className="col tight"><div className="eyebrow">ความพร้อมของช่างในทีม</div>${ws.map(w=>{const b=workerBlockers(w,j.scg_company_id,pv.hazards,j.start_date,wah);return html`<div key=${w.id} className="between sm"><span>${w.full_name} <span className="muted">${w.position||''}</span></span>${b.length?html`<span className="xs" style=${{color:'var(--stop)',textAlign:'right'}}>${b.join(', ')}</span>`:html`<${Chip} c="go" t="พร้อม"/>`}</div>`})}</div>`:null}
  </${Sheet}>`}

/* ---------- Safety Check-in ---------- */
const HC_OK=h=>h&&+h.pulse>=60&&+h.pulse<=100&&+h.sys>=90&&+h.sys<=140&&+h.dia>=60&&+h.dia<=90&&h.alcohol!==''&&+h.alcohol===0;
function CheckinSheet({id}){useStore();const j=byId(S.jobs,id);const p=projOf(j.project_id);const key='ss.ci.'+id+'.'+today();const co=j.scg_company_id;
  const rules=sett('rules',co)||{};const topics=sett('toolbox',co)||[];const topic=topics.length?topics[(new Date().getDate()+j.po_no.length)%topics.length]:'';
  const wx=useWeather([j])[j.id];
  const init=lsGet(key)||{step:0,loc:null,reason:'',team:null,workers:teamWorkers(j.team_id).filter(w=>!workerBlockers(workerOf(w),co,j.hazards,today(),false).length),wah:[],health:{},tbt:false,rules:false,ans:{},site:null,wx:'',lang:lsGet('ss.lang')||'th'};
  const [s,setS]=useState(init);const up=o=>setS(x=>{const n={...x,...(typeof o==='function'?o(x):o)};lsSet(key,n);return n});
  const hasWah=(j.hazards||[]).includes('wah');const wahOn=hasWah&&s.wx!=='ground_only';
  const secs=checklistFor(j,wahOn);const lang=s.lang;
  const steps=['ตำแหน่ง/อากาศ','ทีม',...(wahOn?['ตรวจสุขภาพ']:[]),'Toolbox',...secs.map(x=>x.title),'ยืนยัน'];const st=Math.min(s.step,steps.length-1);const name=steps[st];
  const secIdx=st-(wahOn?4:3);const sec=secs[secIdx];
  const comp=S.workers.filter(w=>w.contractor_id===j.contractor_id&&w.active);
  const dist=s.loc&&j.lat?distM(j.lat,j.lng,s.loc.lat,s.loc.lng):null;const far=dist!=null&&dist>(rules.radius_m||200);
  const getLoc=()=>new Promise(res=>{if(!navigator.geolocation){UI.toast('อุปกรณ์นี้หาตำแหน่งไม่ได้');return res()}
    navigator.geolocation.getCurrentPosition(g3=>{up({loc:{lat:g3.coords.latitude,lng:g3.coords.longitude,acc:Math.round(g3.coords.accuracy)}});res()},e=>{UI.toast('เปิดสิทธิ์ตำแหน่ง (Location) ในเบราว์เซอร์ก่อน');res()},{enableHighAccuracy:true,timeout:15000})});
  const setAns=(c,o)=>up(x=>({ans:{...x.ans,[c]:{...(x.ans[c]||{}),...o}}}));
  const hOf=w=>s.health[w]||{};const setH=(w,o,retest)=>up(x=>({health:{...x.health,[w]:retest?{...(x.health[w]||{}),re:{...((x.health[w]||{}).re||{}),...o}}:{...(x.health[w]||{}),...o}}}));
  const hPass=w=>{const h=hOf(w);return HC_OK(h)&&h.photo||(h.re&&HC_OK(h.re)&&h.re.photo)};
  const rulesAll=secs.flatMap(x=>x.rules||[]);
  const secErr=sc=>sc.items.filter(it=>!(it.setup&&wahOn)).map(it=>{const a=s.ans[it.code]||{};if(!a.v)return'ยังไม่ตอบข้อ '+it.code;if(a.v==='fail'&&!a.photo)return'ข้อไม่ผ่านต้องมีรูป ('+it.code+')';if(a.v==='fail'&&it.crit&&!a.fixed_photo)return'ข้อวิกฤต '+it.code+' ต้องแก้และถ่ายรูปหลังแก้';return null}).filter(Boolean)[0];
  const wxNeed=hasWah&&wx&&['warn','stop'].includes(wx.level);
  const err=name==='ตำแหน่ง/อากาศ'?(!s.loc?'กดหาตำแหน่งก่อน':far&&!s.reason.trim()?'อยู่นอกรัศมี ต้องใส่เหตุผล':wxNeed&&!s.wx?'เลือกการจัดการสภาพอากาศ':wx&&wx.level==='stop'&&hasWah&&s.wx!=='ground_only'?'อากาศระดับหยุดงานบนที่สูง: ทำเฉพาะงานที่พื้น หรือเลื่อนงาน':null)
    :name==='ทีม'?(!s.team?'ถ่ายรูปทีมรวม':!s.workers.length?'เลือกช่างที่มาวันนี้':s.workers.some(w=>workerBlockers(workerOf(w),co,j.hazards,today(),false).length)?'มีช่างที่เข้างานไม่ได้ เอาออกก่อน':wahOn&&s.wah.length<2?'เลือกคนขึ้นที่สูงอย่างน้อย 2 คน (Buddy)':wahOn&&s.wah.some(w=>workerBlockers(workerOf(w),co,j.hazards,today(),true).length)?'มีคนขึ้นที่สูงที่ไม่ผ่านคุณสมบัติ':null)
    :name==='ตรวจสุขภาพ'?(s.wah.find(w=>!hPass(w))?'ยังตรวจไม่ครบหรือมีคนไม่ผ่าน: '+workerName(s.wah.find(w=>!hPass(w)))+' (เอาออกจากรายชื่อขึ้นที่สูงได้)':s.wah.length<2?'คนขึ้นที่สูงเหลือน้อยกว่า 2 คน':null)
    :name==='Toolbox'?(!s.tbt?'ยืนยันว่าประชุมแล้ว':rulesAll.length&&!s.rules?'ทีมต้องรับทราบกฎระหว่างทำงาน':null)
    :sec?secErr(sec):(!s.site?'ถ่ายรูปจุดทำงาน':null);
  const submit=async()=>{const health=s.wah.flatMap(w=>{const h=hOf(w);const a=[{worker_id:w,pulse:+h.pulse,sys:+h.sys,dia:+h.dia,alcohol:+h.alcohol,photo:h.photo}];if(h.re)a.push({worker_id:w,pulse:+h.re.pulse,sys:+h.re.sys,dia:+h.re.dia,alcohol:+h.re.alcohol,photo:h.re.photo,retest:true});return a});
    const r=await act(()=>rpc('submit_checkin',{p_job:id,p_payload:{lat:s.loc?.lat,lng:s.loc?.lng,out_of_radius_reason:s.reason,worker_ids:s.workers,wah_worker_ids:wahOn?s.wah:[],health:wahOn?health:[],
      answers:s.ans,photos:{team:s.team,site:s.site},toolbox_topic:topic,rules_ack:true,weather:wx?{level:wx.level,text:wx.text}:{level:'ok'},weather_choice:s.wx||null,setup_worker_ids:j.setup_worker_ids||[]}}));
    if(r){lsSet(key,null);try{navigator.vibrate&&navigator.vibrate(120)}catch(e){}UI.replace(html`<${PassSheet} token=${r.token} findings=${r.findings}/>`,'บัตรผ่าน')}};
  const stampL=['PO '+j.po_no+' · '+(j.house_no||'')];
  const langSel=html`<div className="lang" role="group" aria-label="ภาษา">${LANGS.map(([k,l])=>html`<button key=${k} className=${lang===k?'on':''} onClick=${()=>{lsSet('ss.lang',k);up({lang:k})}}>${l}</button>`)}</div>`;
  return html`<${Sheet} title="Safety Check-in" sub=${jtNames(j)+' · '+(j.house_no||'–')+' · '+(p?.name||'')} head=${langSel}
    foot=${html`<div className="col tight" style=${{width:'100%'}}>${err?html`<div className="xs" style=${{color:'var(--warn)'}}>${err}</div>`:null}<div className="row">${st>0?html`<${Btn} onClick=${()=>up({step:st-1})}>ย้อนกลับ</${Btn}>`:null}
      <div className="grow"></div>${st<steps.length-1?html`<${Btn} kind="primary" disabled=${!!err} onClick=${()=>{up({step:st+1});document.querySelector('.sheet-b')?.scrollTo(0,0)}}>ถัดไป ›</${Btn}>`:html`<${Btn} kind="go" big=${true} disabled=${!!err} onClick=${submit}>ส่ง Check-in</${Btn}>`}</div></div>`}>
    <div className="col tight"><${Stepper} n=${steps.length} i=${st}/><div className="xs muted">ขั้น ${st+1}/${steps.length} · ${name}</div></div>

    ${name==='ตำแหน่ง/อากาศ'?html`<div className="col"><${Btn} kind="dark" icon="map" onClick=${getLoc}>${s.loc?'หาตำแหน่งใหม่':'หาตำแหน่งปัจจุบัน'}</${Btn}>
      ${s.loc?html`<${Banner} kind=${far?'warn':'go'}>${j.lat?`ห่างจากบ้าน ${dist} ม.`:'ยังไม่มีพิกัดบ้าน ระบบจะใช้ตำแหน่งนี้เป็นพิกัดบ้าน'} (แม่นยำ ±${s.loc.acc} ม.)</${Banner}>`:null}
      ${far?html`<${Field} label="เหตุผลที่อยู่นอกรัศมี"><${Txt} v=${s.reason} set=${v=>up({reason:v})} ph="เช่น จอดรถหน้าโครงการ / GPS คลาดเคลื่อน"/></${Field}>`:null}
      <div className=${'wx '+(wx?wx.level:'na')}><span className="ic-circle"><${Ic} n=${wx?WXL[wx.level][1]:'cloud'}/></span><div className="grow"><b>${wx?WXL[wx.level][2]:'ดูพยากรณ์ไม่ได้'}</b><div className="sm">${wx?wx.text:'ตรวจสภาพอากาศที่หน้างานด้วยตัวเอง'}</div></div></div>
      ${wxNeed?html`<div className="choices">
        ${wx.level==='warn'?html`<button className=${cx('choice',s.wx==='ack'&&'on')} onClick=${()=>up({wx:'ack'})}><span className="t">รับทราบและจัดการแล้ว</span><span className="sm muted">วางแผนลงจากที่สูงก่อนช่วงเสี่ยง</span></button>`:null}
        <button className=${cx('choice',s.wx==='ground_only'&&'on')} onClick=${()=>up({wx:'ground_only',wah:[]})}><span className="t">ทำเฉพาะงานที่พื้นวันนี้</span><span className="sm muted">ระบบแจ้ง IC ให้ทราบ</span></button>
        <button className="choice" onClick=${()=>{lsSet(key,null);UI.close();UI.toast('เลื่อนงาน: แจ้ง IC ของโครงการทางโทรศัพท์/LINE')}}><span className="t">เลื่อนงาน</span><span className="sm muted">ปิดหน้านี้ ไม่ check-in</span></button></div>`:null}
    </div>`:null}

    ${name==='ทีม'?html`<div className="col"><${Upload} label="รูปทีมรวม (เห็นหน้าและ PPE ทุกคน)" camera=${true} stamp=${stampL} value=${s.team} onChange=${v=>up({team:v})}/>
      <div className="eyebrow">ช่างที่มาทำงานวันนี้</div>
      ${comp.map(w=>{const b=workerBlockers(w,co,j.hazards,today(),false);const on=s.workers.includes(w.id);return html`<${Check} key=${w.id} on=${on} disabled=${b.length&&!on} set=${v=>up(x=>({workers:v?[...x.workers,w.id]:x.workers.filter(i=>i!==w.id),wah:v?x.wah:x.wah.filter(i=>i!==w.id)}))}>
        ${w.full_name} <span className="sm muted">${w.position||''}</span>${b.length?html`<div className="xs" style=${{color:'var(--stop)'}}>${b.join(', ')}</div>`:null}</${Check}>`})}
      ${wahOn?html`<div className="eyebrow" style=${{marginTop:8}}>ใครขึ้นที่สูงวันนี้ (≥ 2 คน · ต้องตรวจสุขภาพ)</div>
        ${s.workers.map(workerOf).filter(Boolean).map(w=>{const b=workerBlockers(w,co,j.hazards,today(),true);const on=s.wah.includes(w.id);return html`<${Check} key=${w.id} on=${on} disabled=${b.length&&!on} set=${v=>up(x=>({wah:v?[...x.wah,w.id]:x.wah.filter(i=>i!==w.id)}))}>
          <${Ic} n="wah" s=${16}/> ${w.full_name}${b.length?html`<div className="xs" style=${{color:'var(--stop)'}}>${b.join(', ')}</div>`:null}</${Check}>`})}`:null}
    </div>`:null}

    ${name==='ตรวจสุขภาพ'?html`<div className="col"><${Banner} kind="info">เกณฑ์: ชีพจร 60–100 · ความดัน 90–140 / 60–90 · แอลกอฮอล์ 0 mg% · ถ่ายรูปหน้าจอเครื่องวัด · ค่าที่วัดเห็นเฉพาะผู้ดูแลบริษัทและ SCG Safety</${Banner}>
      ${s.wah.map(w=>{const h=hOf(w);const ok=HC_OK(h);const done=h.pulse&&h.sys&&h.dia&&h.alcohol!==undefined&&h.alcohol!=='';return html`<div key=${w} className=${cx('card pad col tight',done&&!ok&&'failc')}>
        <div className="between"><b>${workerName(w)}</b>${hPass(w)?html`<${Chip} c="go" t="ผ่าน"/>`:done&&!ok?html`<${Chip} c="stop" t="ไม่ผ่าน"/>`:null}</div>
        <${HealthInputs} h=${h} set=${o=>setH(w,o)} stamp=${[...stampL,workerName(w)]}/>
        ${done&&!ok?html`<${Banner} kind="warn">นอกเกณฑ์: พัก 15 นาทีแล้ววัดซ้ำ 1 ครั้ง ถ้ายังไม่ผ่าน ขึ้นที่สูงวันนี้ไม่ได้ (ทำงานที่พื้นได้)</${Banner}>
          <div className="eyebrow">วัดซ้ำ</div><${HealthInputs} h=${h.re||{}} set=${o=>setH(w,o,true)} stamp=${[...stampL,workerName(w),'วัดซ้ำ']}/>
          ${h.re&&h.re.pulse&&!HC_OK(h.re)?html`<${Btn} kind="danger" small=${true} onClick=${()=>up(x=>({wah:x.wah.filter(i=>i!==w)}))}>เอาออกจากรายชื่อขึ้นที่สูง</${Btn}>`:null}`:null}
      </div>`})}</div>`:null}

    ${name==='Toolbox'?html`<div className="col"><div className="card pad col tight"><div className="eyebrow">หัวข้อวันนี้</div><h3>${topic}</h3>
        <div className="row"><${Btn} small=${true} icon="speaker" onClick=${()=>speak(topic,'th')}>อ่านออกเสียง</${Btn}></div></div>
      <div className="card pad col tight"><div className="eyebrow">แผนฉุกเฉิน</div><div className="sm">โทร <b className="num">1669</b> · โรงพยาบาลใกล้ที่สุด: <b>${p?.hospital||'ยังไม่ได้ตั้งค่า'}</b>${p?.hospital_phone?' · '+p.hospital_phone:''}${p?.hospital_km?' · '+p.hospital_km+' กม.':''}</div>
        <div className="sm">IC ของโครงการ: ${profName(p?.ic_id)} ${profOf(p?.ic_id)?.phone?html`· <a href=${'tel:'+profOf(p.ic_id).phone}>${profOf(p.ic_id).phone}</a>`:''}</div></div>
      ${rulesAll.length?html`<div className="eyebrow">กฎระหว่างทำงาน (ใช้เป็นข้อสังเกตพฤติกรรมใน Line Walk)</div>${rulesAll.map(r=>html`<div key=${r.code} className="ruleitem"><${Ill} k=${r.ill} s=${52}/><div className="grow"><div>${r.text}</div>${lang!=='th'?html`<div className="sm tr">${tr(r,lang)}</div>`:null}</div><button className="x" aria-label="อ่านออกเสียง" onClick=${()=>speak(tr(r,lang),lang)}><${Ic} n="speaker"/></button></div>`)}
        <${Check} on=${s.rules} set=${v=>up({rules:v})}>ทีมรับทราบกฎระหว่างทำงานทุกข้อ</${Check}>`:null}
      <${Check} on=${s.tbt} set=${v=>up({tbt:v})}>ประชุม Toolbox Talk กับทีมแล้ว</${Check}></div>`:null}

    ${sec?html`<div className="col"><div className="sec-title"><span className="no">${sec.code}</span><h3>${sec.title}</h3><span className="xs muted">${sec.items.length} ข้อ</span></div>
      ${sec.items.map(it=>{const a=s.ans[it.code]||{};if(it.setup&&wahOn)return html`<div key=${it.code} className="ckitem setup"><${Ill} k=${it.ill}/><div className="grow"><div className="ckt">${it.text}</div><div className="sm" style=${{color:'var(--orange)'}}>ส่งรูปข้อนี้ในขั้นบัตรส้มหลังติดตั้งเสร็จ</div></div></div>`;
        return html`<div key=${it.code} className=${cx('ckitem',it.crit&&'crit',a.v==='fail'&&'fail')}>
        <div className="ckhead"><${Ill} k=${it.ill}/><div className="grow"><div className="ckt">${it.text}</div>${lang!=='th'?html`<div className="sm tr">${tr(it,lang)}</div>`:null}
          <div className="row" style=${{gap:6,marginTop:4}}><span className="xs muted num">${it.code}</span>${it.crit?html`<${Chip} c="stop" t=${it.lsr?'★ LSR '+it.lsr:'★ วิกฤต'}/>`:null}</div></div>
          <button className="x" aria-label="อ่านออกเสียง" onClick=${()=>speak(tr(it,lang),lang)}><${Ic} n="speaker"/></button></div>
        <${PFN} v=${a.v} na=${it.na} set=${v=>setAns(it.code,{v})}/>
        ${a.v==='fail'?html`<${Upload} label="รูปจุดที่ไม่ผ่าน" camera=${true} stamp=${stampL} value=${a.photo} onChange=${v=>setAns(it.code,{photo:v})}/>
          ${it.crit?html`<${Banner} kind="warn">ข้อวิกฤต: ต้องแก้ไขให้เรียบร้อยก่อนเริ่มงาน แล้วถ่ายรูปหลังแก้</${Banner}><${Upload} label="รูปหลังแก้ไข" camera=${true} stamp=${stampL} value=${a.fixed_photo} onChange=${v=>setAns(it.code,{fixed_photo:v})}/>`
            :html`<div className="xs muted">เริ่มงานได้ ระบบเปิดเรื่องให้แก้ภายใน ${(sett('sla',co)||{}).finding_hours||48} ชม.</div>`}`:null}
      </div>`})}</div>`:null}

    ${st===steps.length-1?html`<div className="col"><${Upload} label="รูปจุดทำงาน" camera=${true} stamp=${stampL} value=${s.site} onChange=${v=>up({site:v})}/>
      <div className="card pad col tight"><div className="sm">ช่าง ${s.workers.length} คน${wahOn?' · ขึ้นที่สูง '+s.wah.length+' คน':''} · ${Object.values(s.ans).filter(a=>a.v==='fail').length} ข้อไม่ผ่าน${s.wx==='ground_only'?' · ทำเฉพาะงานที่พื้น':''}</div>
      ${wahOn&&setupItems(j).length?html`<div className="sm" style=${{color:'var(--orange)'}}>หลังส่ง ได้บัตรส้มก่อน: ให้ ${(j.setup_worker_ids||[]).length?j.setup_worker_ids.map(workerName).join(', '):'คนขึ้นที่สูง 2 คนแรก'} ขึ้นติดจุดยึด/ทางเดิน แล้วส่งรูปภายใน ${rules.setup_minutes||60} นาที</div>`:null}
      <div className="xs muted">ระบบตรวจสิทธิ์ช่าง ใบอนุญาต และเช็กลิสต์อีกครั้งก่อนออกบัตรผ่าน</div></div></div>`:null}
  </${Sheet}>`}
function HealthInputs({h,set,stamp}){return html`<div className="col tight"><div className="hgrid">
    <${Field} label="ชีพจร (ครั้ง/นาที)"><${Inp} v=${h.pulse} set=${v=>set({pulse:v})} mode="numeric" max=${3}/></${Field}>
    <${Field} label="ความดันตัวบน"><${Inp} v=${h.sys} set=${v=>set({sys:v})} mode="numeric" max=${3}/></${Field}>
    <${Field} label="ความดันตัวล่าง"><${Inp} v=${h.dia} set=${v=>set({dia:v})} mode="numeric" max=${3}/></${Field}>
    <${Field} label="แอลกอฮอล์ (mg%)"><${Inp} v=${h.alcohol} set=${v=>set({alcohol:v})} mode="decimal" max=${4}/></${Field}></div>
    <${Upload} compact=${true} label="รูปหน้าจอเครื่องวัด" camera=${true} bucket="health" stamp=${stamp} value=${h.photo} onChange=${v=>set({photo:v})}/></div>`}
const distM=(a,b,c,d)=>{const r=x=>x*Math.PI/180;const h=Math.sin(r(c-a)/2)**2+Math.cos(r(a))*Math.cos(r(c))*Math.sin(r(d-b)/2)**2;return Math.round(2*6371000*Math.asin(Math.sqrt(h)))};

/* ---------- บัตรผ่าน 2 ขั้น ---------- */
const passUrl=t=>location.origin+location.pathname+'#pass-'+t;
function QR({text,size}){const [svg,set]=useState('');useEffect(()=>{loadScript('https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js','qrcode').then(q2=>{const c=q2(0,'M');c.addData(text);c.make();set(c.createSvgTag({cellSize:4,margin:2,scalable:true}))}).catch(()=>{})},[text]);
  return html`<div className="qrbox" style=${{width:size||180,height:size||180}} dangerouslySetInnerHTML=${{__html:svg}}></div>`}
function Countdown({to}){const [n,setN]=useState(Date.now());useEffect(()=>{const t=setInterval(()=>setN(Date.now()),1000);return()=>clearInterval(t)},[]);
  const s=Math.round((new Date(to)-n)/1000);const a=Math.abs(s);return html`<span className="num">${s<0?'เกิน ':''}${z(Math.floor(a/60))}:${z(a%60)}</span>`}
function PassSheet({token,findings}){useStore();const ci=S.checkins.find(c=>c.pass_token===token);const j=ci&&byId(S.jobs,ci.job_id);const [ph,setPh]=useState({});
  if(!ci)return html`<${Sheet} title="บัตรผ่าน"><div className="sm muted">กำลังโหลด…</div></${Sheet}>`;
  const items=ci.stage==='setup'?setupItems(j):[];const closed=closeOf(ci.id);const setup=ci.stage==='setup';
  return html`<${Sheet} title="บัตรผ่านวันนี้" sub=${jtNames(j)+' · '+(j.house_no||'')}>
    <div className=${cx('pass2',setup?'orange':'green',(ci.voided||closed)&&'void')}>
      <div className="eyebrow">${thDL(ci.work_date)} · ${coName(j.scg_company_id)}</div>
      <h1>${ci.voided?'ยกเลิก · หยุดงาน':closed?'ปิดงานแล้ว':setup?'ขั้นติดตั้ง':'ทำงาน'}</h1>
      ${setup&&!ci.voided?html`<div className="big">${html`<${Countdown} to=${ci.setup_due}/>`}</div><div className="sm">ขึ้นที่สูงได้เฉพาะ <b>${(ci.setup_worker_ids||[]).map(workerName).join(', ')||'คนติดตั้ง'}</b> · ${j.setup_method||'ติดจุดยึด/ทางเดิน'} · ส่งรูปให้ครบเพื่อเปลี่ยนเป็นบัตรเขียว</div>`
        :html`<div className="sm">${ci.voided?ci.void_reason:closed?'ปิดงาน '+hm(closed.created_at):'ทุกคนในรายชื่อทำงานได้ · คนขึ้นที่สูงตามรายชื่อเท่านั้น'}</div>`}
      <${QR} text=${passUrl(token)}/>
      <div className="ppl sm">${ci.worker_ids.map(w=>html`<div key=${w} className="between"><span>${workerName(w)}</span><span>${(ci.setup_worker_ids||[]).includes(w)&&setup?'ติดตั้ง':(ci.wah_worker_ids||[]).includes(w)?'ขึ้นที่สูง':'งานพื้น'}</span></div>`)}</div>
      <div className="xs" style=${{opacity:.85}}>Check-in ${hm(ci.created_at)}${ci.late?' · สาย':''} · ให้ SCG สแกนตรวจได้ตลอดวัน</div></div>
    ${setup&&!ci.voided&&isContractor()?html`<div className="col"><div className="eyebrow">ส่งรูปหลังติดตั้ง</div>
      ${items.map(it=>html`<div key=${it.code} className="col tight"><div className="row"><${Ill} k=${it.ill} s=${44}/><span className="sm grow">${it.text}</span></div>
        <${Upload} label=${'รูป '+it.code} camera=${true} stamp=${['PO '+j.po_no,'ขั้นติดตั้ง '+it.code]} value=${ph[it.code]} onChange=${v=>setPh(o=>({...o,[it.code]:v}))}/></div>`)}
      <${Btn} kind="go" big=${true} block=${true} disabled=${items.some(it=>!ph[it.code])} onClick=${async()=>{const r=await act(()=>rpc('submit_setup',{p_checkin:ci.id,p_photos:ph}));if(r)UI.toast(r.late?'บัตรเขียวแล้ว (ส่งช้ากว่ากำหนด แจ้ง IC)':'บัตรเขียวแล้ว ทุกคนเริ่มงานได้')}}>ส่งรูป → บัตรเขียว</${Btn}>
      <${Btn} kind="danger" block=${true} onClick=${()=>UI.open(html`<${IncidentSheet} job=${j.id} kind="unsafe_condition" text="ไม่มีจุดยึดที่เหมาะสม หยุดงานที่สูงของบ้านนี้"/>`,'แจ้งเหตุ')}>ไม่มีจุดยึดที่เหมาะสม → หยุดงานที่สูง แจ้ง IC</${Btn}></div>`:null}
    ${findings?html`<${Banner} kind="warn">มีข้อบกพร่อง ${findings} ข้อ แก้ไขในเมนู "ต้องแก้" ภายในกำหนด</${Banner}>`:null}</${Sheet}>`}

/* ---------- ปิดงาน ---------- */
function CloseoutSheet({cid}){useStore();const ci=byId(S.checkins,cid);const j=byId(S.jobs,ci.job_id);const items=sett('closeout',j.scg_company_id)||[];
  const [a,setA]=useState({});const [ph,setPh]=useState([null,null]);const [dmg,setDmg]=useState(false);const [note,setNote]=useState('');const [inc,setInc]=useState(null);const [fin,setFin]=useState(today()===j.end_date);
  const ok=items.every(i=>a[i.code])&&ph[0]&&ph[1]&&(!dmg||note.trim())&&inc!==null;const stampL=['ปิดงาน PO '+j.po_no];
  return html`<${Sheet} title="ปิดงานประจำวัน" sub=${(j.house_no||'')+' · '+thDL(ci.work_date)} foot=${html`<${Btn} kind="dark" block=${true} disabled=${!ok} onClick=${async()=>{
      const r=await act(()=>rpc('submit_closeout',{p_checkin:cid,p_payload:{answers:Object.fromEntries(Object.entries(a).map(([k,v])=>[k,v])),photos:{after:ph},damage:dmg,damage_note:note,incident:inc,final:fin}}),fin?'ปิดงานจบแล้ว':'ปิดงานวันนี้แล้ว');
      if(r){if(inc)UI.replace(html`<${IncidentSheet} job=${j.id} kind="near_miss"/>`,'แจ้งเหตุ');else UI.close()}}}>${fin?'ปิดงานจบ':'ปิดงานวันนี้'}</${Btn}>`}>
    ${items.map(i=>html`<div key=${i.code} className="card pad col tight"><div className="row"><span className="xs muted num">${i.code}</span>${i.crit?html`<${Chip} c="stop" t="★"/>`:null}<span className="grow">${i.text}</span></div><${Seg} v=${a[i.code]} set=${v=>setA(o=>({...o,[i.code]:v}))} opts=${[['pass','เรียบร้อย'],['na','ไม่เกี่ยว']]}/></div>`)}
    <div className="card pad col tight"><div className="row"><span className="xs muted num">Z9</span><${Chip} c="stop" t="★"/><span className="grow">วันนี้มีเหตุ เกือบเกิดเหตุ หรือคนเจ็บไหม</span></div><${Seg} v=${inc===null?'':inc?'y':'n'} set=${v=>setInc(v==='y')} opts=${[['n','ไม่มี'],['y','มี → แจ้งเหตุต่อ']]}/></div>
    <div className="card pad col tight"><div className="row"><span className="xs muted num">Z10</span><span className="grow">ความเสียหายต่อทรัพย์สินบ้านลูกค้า/บุคคลที่ 3</span></div><${Seg} v=${dmg?'y':'n'} set=${v=>setDmg(v==='y')} opts=${[['n','ไม่มี'],['y','มี']]}/>
      ${dmg?html`<${Field} label="อธิบายความเสียหาย"><${Txt} v=${note} set=${setNote}/></${Field}>`:null}</div>
    <${Upload} label="รูปหลังเลิกงาน 1" camera=${true} stamp=${stampL} value=${ph[0]} onChange=${v=>setPh(o=>[v,o[1]])}/><${Upload} label="รูปหลังเลิกงาน 2" camera=${true} stamp=${stampL} value=${ph[1]} onChange=${v=>setPh(o=>[o[0],v])}/>
    <${Check} on=${fin} set=${setFin}>งานบ้านนี้เสร็จแล้ว (ปิดงานจบ)</${Check}>
  </${Sheet}>`}

/* ---------- ต้องแก้ ---------- */
function CTodo(){useStore();const un=S.notifs.filter(n=>n.need_ack&&!n.ack_at);const fs=S.findings.filter(f=>['open','fixed'].includes(f.status)&&inCo(f.scg_company_id));const info=S.notifs.filter(n=>!n.need_ack&&!n.ack_at);
  return html`<div className="col"><div className="row"><${Btn} kind="danger" icon="warn" onClick=${()=>UI.open(html`<${IncidentSheet}/>`,'แจ้งเหตุ')}>แจ้งเหตุ / Near miss</${Btn}></div>
    <${Card}><${CardH} icon="bell" title="รอรับทราบ" right=${html`<${Chip} c=${un.length?'stop':'go'} t=${un.length}/>`}/><div className="card-b col tight">${un.length?un.map(n=>html`<${NotifRow} key=${n.id} n=${n}/>`):html`<div className="sm muted">ไม่มี</div>`}</div></${Card}>
    <${Card}><${CardH} icon="flag" title="ข้อบกพร่อง (Findings)"/><div className="card-b col tight">${fs.length?fs.map(f=>html`<${FindingRow} key=${f.id} f=${f}/>`):html`<div className="sm muted">ไม่มี</div>`}</div></${Card}>
    ${info.length?html`<${Card}><${CardH} icon="info" title="แจ้งให้ทราบ" right=${html`<${Btn} small=${true} onClick=${()=>act(()=>rpc('ack_all_info'))}>อ่านแล้วทั้งหมด</${Btn}>`}/><div className="card-b col tight">${info.slice(0,20).map(n=>html`<${NotifRow} key=${n.id} n=${n}/>`)}</div></${Card}>`:null}</div>`}
const F_ST={open:['stop','รอแก้'],fixed:['warn','แก้แล้ว รอตรวจ'],verified:['go','ตรวจผ่าน']};
const SEV={lsr:'LSR',critical:'วิกฤต',high:'สูง',normal:'ปกติ'};
function FindingRow({f}){const j=byId(S.jobs,f.job_id);const late=f.status==='open'&&f.due_at&&new Date(f.due_at)<new Date();
  return html`<button className="li" onClick=${()=>UI.open(html`<${FixSheet} id=${f.id}/>`,f.item_text)}><span className=${'ic-circle '+(f.severity==='lsr'||f.severity==='critical'?'stop':'warn')}><${Ic} n="flag"/></span><div className="grow"><div className="t">${f.severity!=='normal'?SEV[f.severity]+' · ':''}${f.item_text}</div><div className="s">${j?.po_no||''} · ${j?.house_no||''} · ${ctrName(j?.contractor_id)}${f.due_at&&f.status==='open'?' · ครบ '+thT(f.due_at):''}</div></div>
    <div className="row">${late?html`<${Chip} c="stop" t="เกินกำหนด"/>`:null}<${Chip} c=${F_ST[f.status][0]} t=${F_ST[f.status][1]}/></div></button>`}
function FixSheet({id}){useStore();const f=byId(S.findings,id);const j=byId(S.jobs,f.job_id);const [ph,setPh]=useState(null);const [note,setNote]=useState('');const [rn,setRn]=useState('');
  const scgCan=isSCG()&&f.status==='fixed'&&['installation_consultant','ic_qc_manager','safety_admin'].includes(ME.role);
  return html`<${Sheet} title=${f.item_text} sub=${(j?.po_no||'')+' · '+ctrName(j?.contractor_id)} foot=${isContractor()&&f.status==='open'&&f.source!=='stop'?html`<${Btn} kind="primary" block=${true} disabled=${!ph} onClick=${async()=>{if(await act(()=>rpc('fix_finding',{p_finding:id,p_photo:ph,p_note:note}),'แจ้งแก้ไขแล้ว'))UI.close()}}>ส่งผลการแก้ไข</${Btn}>`
      :scgCan?html`<div className="row" style=${{width:'100%'}}><${Btn} kind="danger" onClick=${async()=>{if(!rn.trim())return UI.toast('ใส่เหตุผลที่ไม่ผ่าน');if(await act(()=>rpc('verify_finding',{p_finding:id,p_ok:false,p_note:rn})))UI.close()}}>ไม่ผ่าน</${Btn}><div className="grow"></div><${Btn} kind="go" onClick=${async()=>{if(await act(()=>rpc('verify_finding',{p_finding:id,p_ok:true}),'ตรวจผ่าน'))UI.close()}}>ตรวจผ่าน</${Btn}></div>`:null}>
    <div className="row"><${Chip} c=${F_ST[f.status][0]} t=${F_ST[f.status][1]}/><${Chip} t=${'ระดับ '+SEV[f.severity]}/>${f.due_at?html`<span className="sm muted">ครบกำหนด ${thT(f.due_at)}</span>`:null}</div>
    ${f.source==='stop'?html`<${Banner} kind="stop">จากการสั่งหยุดงาน · ปิดเมื่อ SCG ปลดล็อกงาน</${Banner}>`:null}
    <div className="row">${f.photo_path?html`<div className="col tight"><span className="xs muted">ตอนพบ</span><${Img} path=${f.photo_path} cls="thumb lg"/></div>`:null}${f.fix_photo_path?html`<div className="col tight"><span className="xs muted">หลังแก้</span><${Img} path=${f.fix_photo_path} cls="thumb lg"/></div>`:null}</div>
    ${f.fix_note?html`<div className="sm">หมายเหตุ: ${f.fix_note}</div>`:null}
    ${isContractor()&&f.status==='open'&&f.source!=='stop'?html`<${Upload} label="รูปหลังแก้ไข" camera=${true} stamp=${['แก้ไข PO '+(j?.po_no||'')]} value=${ph} onChange=${setPh}/><${Field} label="รายละเอียดการแก้ไข"><${Txt} v=${note} set=${setNote}/></${Field}>`:null}
    ${scgCan?html`<${Field} label="เหตุผล (ถ้าไม่ผ่าน)"><${Txt} v=${rn} set=${setRn}/></${Field}>`:null}
  </${Sheet}>`}

/* ---------- SOS + แจ้งเหตุ ---------- */
function activeJob(){return visJobs().find(j=>isToday(j)&&ciOf(j.id)&&!closeOf(ciOf(j.id).id))||visJobs().find(j=>isToday(j)&&j.status!=='cancelled')}
async function fireSOS(){const j=activeJob();let loc=null;
  try{loc=await new Promise(r=>navigator.geolocation?navigator.geolocation.getCurrentPosition(x=>r(x.coords),()=>r(null),{timeout:6000}):r(null))}catch(e){}
  const res=await run(()=>rpc('sos',{p_job:j?.id||null,p_lat:loc?.latitude||null,p_lng:loc?.longitude||null,p_co:j?.scg_company_id||(S.co!=='all'?S.co:null)}));
  UI.open(html`<${SOSSheet} j=${j} r=${res||{}}/>`,'SOS');loadAll().catch(()=>{})}
function SOSSheet({j,r}){const p=j&&projOf(j.project_id);const ic=p&&profOf(p.ic_id);
  return html`<${Sheet} title="ฉุกเฉิน" sub=${r.incident?'ส่งแจ้งเตือนด่วนพร้อมพิกัดแล้ว':'ส่งแจ้งเตือนไม่สำเร็จ โทรตามรายการด้านล่าง'}>
    <a className="btn red big block" href="tel:1669"><${Ic} n="phone"/>โทร 1669 (เจ็บป่วยฉุกเฉิน)</a>
    ${ic?.phone||r.ic_phone?html`<a className="btn big block" href=${'tel:'+(r.ic_phone||ic.phone)}><${Ic} n="phone"/>โทร IC: ${r.ic_name||ic.full_name}</a>`:null}
    ${p?.hospital?html`<div className="card pad col tight"><b>${p.hospital}</b><div className="sm muted">${p.hospital_km?p.hospital_km+' กม. · ':''}${p.hospital_phone||''}</div>
      <div className="row">${p.hospital_phone?html`<a className="btn" href=${'tel:'+p.hospital_phone}><${Ic} n="phone"/>โทร</a>`:null}<a className="btn" target="_blank" rel="noopener" href=${'https://www.google.com/maps/search/?api=1&query='+encodeURIComponent(p.hospital)}><${Ic} n="map"/>นำทาง</a></div></div>`:null}
    <${Banner} kind="info">หลังเหตุการณ์ กรอกรายละเอียดเพิ่มในเมนู "แจ้งเหตุ" (ระบบเปิดเรื่องไว้ให้แล้ว)</${Banner}></${Sheet}>`}
const INC_KIND=[['injury','อุบัติเหตุ มีผู้บาดเจ็บ','heart'],['property','ทรัพย์สินเสียหาย','home'],['near_miss','Near miss เกือบเกิดเหตุ','warn'],['unsafe_condition','สภาพไม่ปลอดภัย','flag'],['unsafe_act','พฤติกรรมไม่ปลอดภัย','user']];
function IncidentSheet({job,kind,text}){useStore();const js=visJobs().filter(j=>j.end_date>=addDays(today(),-7));const [k,setK]=useState(kind||'');const [jid,setJ]=useState(job||'');const [t,setT]=useState(text||'');const [ph,setPh]=useState([]);
  const [co,setCo]=useState(S.co&&S.co!=='all'?S.co:myCos()[0]);
  return html`<${Sheet} title="แจ้งเหตุ / Near miss / สภาพไม่ปลอดภัย" foot=${html`<${Btn} kind="red" block=${true} disabled=${!k||(!t.trim()&&!ph.length)} onClick=${async()=>{
      let loc=null;try{loc=await new Promise(r=>navigator.geolocation?navigator.geolocation.getCurrentPosition(x=>r(x.coords),()=>r(null),{timeout:5000}):r(null))}catch(e){}
      if(await act(()=>rpc('report_incident',{p_co:jid?null:co,p_job:jid||null,p_kind:k,p_desc:t,p_photos:ph,p_lat:loc?.latitude||null,p_lng:loc?.longitude||null}),'ส่งแจ้งเหตุแล้ว Safety และ IC ได้รับแจ้ง'))UI.close()}}>ส่งแจ้งเหตุ</${Btn}>`}>
    <div className="choices">${INC_KIND.map(([x,l,ic])=>html`<button key=${x} className=${cx('choice',k===x&&'on')} onClick=${()=>setK(x)}><span className="row"><${Ic} n=${ic}/><span className="t">${l}</span></span></button>`)}</div>
    <${Field} label="งานที่เกี่ยวข้อง (ไม่บังคับ)"><${Sel} v=${jid} set=${setJ} opts=${[['','ไม่ระบุ'],...js.map(j=>[j.id,j.po_no+' · '+(j.house_no||'')+' · '+jtNames(j)])]}/></${Field}>
    ${!jid&&myCos().length>1?html`<${Field} label="บริษัท SCG"><${Sel} v=${co} set=${setCo} opts=${myCos().map(c=>[c,coName(c)])}/></${Field}>`:null}
    <${Field} label="เกิดอะไรขึ้น (1–2 บรรทัด)"><${Txt} v=${t} set=${setT} ph="เช่น บันไดลื่นไถลตอนพาดขึ้นราง ยังไม่มีคนเจ็บ"/></${Field}>
    ${[0,1,2].map(i=>i<=ph.length?html`<${Upload} key=${i} label=${'รูป '+(i+1)} camera=${true} folder=${ME.contractor_id||'scg'} value=${ph[i]} onChange=${v=>setPh(o=>{const n=[...o];n[i]=v;return n.filter(Boolean)})}/>`:null)}
  </${Sheet}>`}

/* ---------- ทีมและช่าง (ผู้ดูแลบริษัท) ---------- */
const W_ST={pending:['warn','รออนุมัติ'],approved:['go','อนุมัติ'],rejected:['stop','ไม่อนุมัติ']};
const NAT={th:'ไทย',mm:'เมียนมา',kh:'กัมพูชา',la:'ลาว',other:'อื่น ๆ'};
function LinkChips({w}){const cos=myCos();return html`<span className="row" style=${{gap:4}}>${cos.map(c=>{const l=linkOf(w.id,c);const ban=l&&(l.banned_forever||(l.banned_until&&l.banned_until>=today()));
  return html`<span key=${c} className=${'lchip '+(ban?'stop':l?W_ST[l.status][0]:'mute')} title=${coName(c)+': '+(ban?'ห้ามทำงาน (LSR)':l?W_ST[l.status][1]:'ยังไม่ขอ')} style=${{'--co':coColor(c)}}>${coShort(c)} ${ban?'⛔':l?l.status==='approved'?'✓':l.status==='pending'?'…':'✕':'–'}</span>`})}</span>`}
function CTeam(){useStore();const [t,setT]=useState('w');const ws=S.workers.filter(w=>w.contractor_id===ME.contractor_id);const teams=S.teams;const [sel,setSel]=useState([]);const [reqCo,setReqCo]=useState(myCos()[0]||'');
  const users=S.profiles.filter(p=>p.contractor_id===ME.contractor_id);const inv=S.invites.filter(i=>i.contractor_id===ME.contractor_id&&!S.profiles.some(p=>p.email.toLowerCase()===i.email.toLowerCase()));
  return html`<div className="col"><${Tabs} v=${t} set=${setT} opts=${[['w','ช่าง',ws.length,'id'],['t','ทีม',teams.length,'team'],['u','ผู้ใช้แอป',users.length,'user']]}/>
    ${t==='w'?html`<div className="row"><${Btn} kind="primary" icon="plus" onClick=${()=>UI.open(html`<${WorkerEdit}/>`,'เพิ่มช่าง')}>เพิ่มช่าง</${Btn}>
        ${sel.length?html`<${Sel} v=${reqCo} set=${setReqCo} opts=${myCos().map(c=>[c,'ขอเข้าทำงานกับ '+coName(c)])}/><${Btn} kind="dark" onClick=${async()=>{if(await act(()=>rpc('request_worker_links',{p_co:reqCo,p_workers:sel}),'ส่งคำขอ '+sel.length+' คนแล้ว'))setSel([])}}>ส่งคำขอ ${sel.length} คน</${Btn}>`:html`<span className="sm muted">ติ๊กเลือกช่างเพื่อขอเข้าทำงานกับบริษัท SCG ทีละหลายคน</span>`}</div>
      <div className="card list">${ws.map(w=>html`<div key=${w.id} className="li wrow">
        <input type="checkbox" aria-label=${'เลือก '+w.full_name} checked=${sel.includes(w.id)} onChange=${e=>setSel(o=>e.target.checked?[...o,w.id]:o.filter(x=>x!==w.id))}/>
        <button className="wbtn" onClick=${()=>UI.open(html`<${WorkerSheet} id=${w.id}/>`,w.full_name)}><${Avatar} n=${w.nickname||w.full_name}/><div className="grow"><div className="t">${w.full_name}</div><div className="s">${w.position||'–'} · ${NAT[w.nationality]}${w.id_verified_at?' · ••'+w.id_last4:' · ยังไม่ตรวจตัวบุคคล'} · cert ${S.certs.filter(c=>c.worker_id===w.id).length}</div>
          <div className="row" style=${{gap:6,marginTop:4}}><${LinkChips} w=${w}/><${Chip} c=${SELFDEC[w.selfdec_status][0]} icon="heart" t=${SELFDEC[w.selfdec_status][1]}/></div></div><${Ic} n="chev"/></button></div>`)}</div>`:null}
    ${t==='t'?html`<div className="row"><${Btn} kind="primary" icon="plus" onClick=${()=>UI.open(html`<${TeamEdit}/>`,'สร้างทีม')}>สร้างทีม</${Btn}></div><div className="g3">${teams.map(x=>html`<button key=${x.id} className="card pad col tight click" style=${{textAlign:'left'}} onClick=${()=>UI.open(html`<${TeamEdit} id=${x.id}/>`,x.name)}><h3>${x.name}</h3><div className="sm muted">หัวหน้าทีม: ${profName(x.lead_id)}</div><div className="avs">${teamWorkers(x.id).map(w=>html`<${Avatar} key=${w} n=${workerOf(w)?.nickname||workerName(w)}/>`)}</div></button>`)}</div>`:null}
    ${t==='u'?html`<${InviteBox} roles=${[['team_lead','หัวหน้าทีมช่าง'],['contractor_admin','ผู้ดูแลบริษัท']]} contractor=${ME.contractor_id} label="เชิญผู้ใช้ของบริษัท (บัญชีรายคน)"/>
      <div className="card"><div className="tbl"><table><thead><tr><th>ชื่อ</th><th>อีเมล</th><th>บทบาท</th><th>LINE</th><th>ใช้งาน</th></tr></thead><tbody>${users.map(u=>html`<tr key=${u.id}><td>${u.full_name||'–'}</td><td className="sm">${u.email}</td><td className="sm">${ROLE_NAME[u.role]}</td><td>${u.line_user_id?html`<${Chip} c="go" t="ผูกแล้ว"/>`:html`<${Chip} t="ยังไม่ผูก"/>`}</td>
        <td>${u.id!==ME.id?html`<input type="checkbox" aria-label="ใช้งาน" checked=${u.active} onChange=${e=>act(()=>rpc('set_user',{p_id:u.id,p_role:u.role,p_active:e.target.checked}),'บันทึกแล้ว')}/>`:'–'}</td></tr>`)}
        ${inv.map(i=>html`<tr key=${i.email}><td>${i.full_name||'–'}</td><td className="sm">${i.email}</td><td className="sm">${ROLE_NAME[i.role]}</td><td colspan="2"><${Chip} c="warn" t="รอเข้าระบบครั้งแรก"/></td></tr>`)}</tbody></table></div></div>`:null}
  </div>`}
function InviteBox({roles,contractor,cos,label}){const [e,setE]=useState('');const [n,setN]=useState('');const [r,setR]=useState(roles[0][0]);
  return html`<${Card} pad=${true} className="col tight"><b>${label}</b><div className="fgrid"><${Inp} v=${n} set=${setN} ph="ชื่อ-นามสกุล"/><${Inp} v=${e} set=${setE} type="email" ph="อีเมล"/>
    ${roles.length>1?html`<${Sel} v=${r} set=${setR} opts=${roles}/>`:null}
    <${Btn} kind="dark" disabled=${!/.+@.+\..+/.test(e)} onClick=${async()=>{if(await act(()=>rpc('invite_user',{p_email:e,p_name:n,p_role:r,p_cos:cos||[],p_contractor:contractor||null}),'บันทึกคำเชิญแล้ว ส่งลิงก์แอปให้ผู้ใช้เข้าด้วยอีเมลนี้')){setE('');setN('')}}}>บันทึกคำเชิญ</${Btn}></div>
    <div className="xs muted">ผู้ใช้เปิดลิงก์แอปแล้วเข้าสู่ระบบด้วยอีเมลที่เชิญ ระบบให้สิทธิ์ตามบทบาทอัตโนมัติ</div></${Card}>`}
function WorkerEdit({id}){const w=id?byId(S.workers,id):{};const [f,setF]=useState({full_name:w.full_name||'',nickname:w.nickname||'',position:w.position||'',nationality:w.nationality||'th',phone:w.phone||'',birth_date:w.birth_date||'',photo_path:w.photo_path||null,
    foreign_worker:!!w.foreign_worker,work_permit_expiry:w.work_permit_expiry||'',insurance_no:w.insurance_no||'',insurance_expiry:w.insurance_expiry||'',id_image_path:w.id_image_path||null});
  const [cos,setCos]=useState(id?[]:myCos().filter(c=>ctrLink(ME.contractor_id,c)?.status==='approved'));
  const set=k=>v=>setF(o=>({...o,[k]:v}));const ok=f.full_name.trim()&&f.position&&f.birth_date&&(id||f.id_image_path);
  const save=()=>act(async()=>{const row={...f,birth_date:f.birth_date||null,work_permit_expiry:f.work_permit_expiry||null,insurance_expiry:f.insurance_expiry||null,foreign_worker:f.nationality!=='th'||f.foreign_worker};
    if(id){const r=await sb.from('workers').update(row).eq('id',id);if(r.error)throw r.error}
    else{const r=await sb.from('workers').insert({...row,contractor_id:ME.contractor_id}).select().single();if(r.error)throw r.error;for(const c of cos)await rpc('request_worker_links',{p_co:c,p_workers:[r.data.id]})}
    UI.close()},id?'บันทึกแล้ว':'เพิ่มช่างแล้ว รอ SCG ตรวจตัวบุคคลและอนุมัติ');
  return html`<${Sheet} title=${id?'แก้ข้อมูลช่าง':'เพิ่มช่าง'} foot=${html`<${Btn} kind="primary" block=${true} disabled=${!ok} onClick=${save}>${id?'บันทึก':'บันทึกและส่งคำขอ'}</${Btn}>`}>
    <${Banner} kind="info">กรอกครั้งเดียวใช้ได้ทุกบริษัท SCG · ห้ามรับเหมาช่วง ช่างทุกคนต้องเป็นของบริษัทคุณ</${Banner}>
    <div className="fgrid"><${Field} label="ชื่อ-นามสกุล"><${Inp} v=${f.full_name} set=${set('full_name')}/></${Field}><${Field} label="ชื่อเล่น"><${Inp} v=${f.nickname} set=${set('nickname')}/></${Field}>
      <${Field} label="ตำแหน่งงาน (ตาม Training Matrix)"><${Sel} v=${f.position} set=${set('position')} opts=${['','หัวหน้างาน/Foreman','ช่างหลังคา','ช่างเชื่อม','ช่างไฟฟ้า','ช่างไม้','ช่างทั่วไป','ผู้ช่วยช่าง','ผู้ควบคุมรอก/ปั้นจั่น','ช่างนั่งร้าน']}/></${Field}>
      <${Field} label="สัญชาติ"><${Sel} v=${f.nationality} set=${set('nationality')} opts=${Object.entries(NAT)}/></${Field}>
      <${Field} label="วันเกิด" hint="งานที่สูงต้องอายุ 18 ปีขึ้นไป"><${Inp} type="date" v=${f.birth_date} set=${set('birth_date')}/></${Field}><${Field} label="เบอร์โทร"><${Inp} v=${f.phone} set=${set('phone')} mode="tel"/></${Field}>
      <${Field} label="เลขประกันสังคม/กรมธรรม์"><${Inp} v=${f.insurance_no} set=${set('insurance_no')}/></${Field}><${Field} label="ประกันหมดอายุ"><${Inp} type="date" v=${f.insurance_expiry} set=${set('insurance_expiry')}/></${Field}>
      ${f.nationality!=='th'?html`<${Field} label="Work permit หมดอายุ"><${Inp} type="date" v=${f.work_permit_expiry} set=${set('work_permit_expiry')}/></${Field}>`:null}</div>
    <${Upload} label="รูปหน้าช่าง" camera=${true} value=${f.photo_path} onChange=${set('photo_path')}/>
    ${!id||!w.id_verified_at?html`<${Upload} label="รูปบัตรประชาชน / บัตรชมพู / Passport (ชั่วคราว)" hint="SCG ใช้ตรวจตัวบุคคลครั้งเดียว แล้วระบบลบรูปทันที เก็บแค่เลขท้าย 4 หลัก" bucket="idcheck" value=${f.id_image_path} onChange=${set('id_image_path')}/>`:null}
    ${!id?html`<div className="eyebrow">ขอเข้าทำงานกับ</div>${myCos().map(c=>html`<${Check} key=${c} on=${cos.includes(c)} set=${v=>setCos(o=>v?[...o,c]:o.filter(x=>x!==c))}><${CoBadge} id=${c}/> ${coName(c)}</${Check}>`)}`:null}
  </${Sheet}>`}
function WorkerSheet({id}){useStore();const w=byId(S.workers,id);if(!w)return null;const cs=S.certs.filter(c=>c.worker_id===id);const cos=isSCG()?myCos():myCos();const flags=S.flags.filter(f=>f.worker_id===id);
  const rv=(c,co)=>S.creviews.find(r=>r.cert_id===c.id&&r.scg_company_id===co);
  return html`<${Sheet} size="wide" title=${w.full_name} sub=${(w.position||'')+' · '+ctrName(w.contractor_id)+' · '+NAT[w.nationality]}>
    <div className="row">${w.photo_path?html`<${Img} path=${w.photo_path} cls="thumb lg"/>`:html`<${Avatar} lg=${true} n=${w.nickname||w.full_name}/>`}
      <div className="col tight"><div className="row">${w.id_verified_at?html`<${Chip} c="go" icon="id" t=${'ตรวจตัวบุคคลแล้ว ••'+w.id_last4}/>`:html`<${Chip} c="warn" icon="id" t="ยังไม่ตรวจตัวบุคคล"/>`}
        <${Chip} c=${SELFDEC[w.selfdec_status][0]} icon="heart" t=${'Self-declaration: '+SELFDEC[w.selfdec_status][1]+(w.selfdec_until?' ถึง '+thD(w.selfdec_until):'')}/></div>
        <div className="xs muted">${w.id_verified_at?'ตรวจโดย '+profName(w.id_verified_by)+' ('+coShort(w.id_verified_company)+') '+thD(w.id_verified_at.slice(0,10)):''}${w.birth_date?' · อายุ '+Math.floor((Date.now()-new Date(w.birth_date))/31557600000)+' ปี':''}${w.foreign_worker?' · Work permit ถึง '+thD(w.work_permit_expiry):''}</div></div></div>
    ${flags.length&&isSCG()?html`<${Banner} kind="stop"><b>Flag กฎพิทักษ์ชีวิต</b>${flags.map(f=>html`<div key=${f.id} className="sm">ข้อ ${f.rule} · ${thD(f.occurred_on)} · ${f.penalty} · ${coName(f.scg_company_id)}</div>`)}</${Banner}>`:null}
    ${isCAdmin()?html`<div className="row"><${Btn} small=${true} icon="edit" onClick=${()=>UI.open(html`<${WorkerEdit} id=${id}/>`,'แก้ข้อมูล')}>แก้ข้อมูล</${Btn}><${Btn} small=${true} icon="plus" onClick=${()=>UI.open(html`<${CertEdit} worker=${id}/>`,'เพิ่ม cert')}>เพิ่ม cert/ผลตรวจ</${Btn}>
      <${Btn} small=${true} icon="heart" onClick=${()=>UI.open(html`<${SelfdecSheet} id=${id}/>`,'Self-declaration')}>Self-declaration</${Btn}></div>`:null}
    <div className="eyebrow">สถานะกับแต่ละบริษัท SCG</div>
    <div className="col tight">${cos.map(c=>{const l=linkOf(id,c);const ban=l&&(l.banned_forever||(l.banned_until&&l.banned_until>=today()));return html`<div key=${c} className="card pad col tight" style=${{borderLeft:'4px solid '+coColor(c)}}>
      <div className="between"><b>${coName(c)}</b>${ban?html`<${Chip} c="stop" t=${l.banned_forever?'ห้ามทำงานตลอดชีพ':'ห้ามทำงานถึง '+thD(l.banned_until)}/>`:l?html`<${Chip} c=${W_ST[l.status][0]} t=${W_ST[l.status][1]}/>`:html`<${Chip} t="ยังไม่ขอ"/>`}</div>
      ${l?.note?html`<div className="xs muted">${l.note}</div>`:null}
      ${isCAdmin()&&(!l||l.status==='rejected')?html`<${Btn} small=${true} onClick=${()=>act(()=>rpc('request_worker_links',{p_co:c,p_workers:[id]}),'ส่งคำขอแล้ว')}>ขอเข้าทำงานกับ ${coShort(c)}</${Btn}>`:null}
      ${isSCG()&&canApproveWorkers()&&l?html`<${WorkerReview} w=${w} co=${c}/>`:null}</div>`})}</div>
    <div className="eyebrow">ใบรับรองและผลตรวจสุขภาพ</div>
    ${cs.length?cs.map(c=>html`<div key=${c.id} className="card pad between"><div className="grow sm"><b>${certName(c.cert_type)}</b><div className="xs muted">${c.expires_on?'หมดอายุ '+thD(c.expires_on):'ไม่มีวันหมดอายุ'}</div>
        <div className="row" style=${{gap:4,marginTop:4}}>${cos.map(co=>{const r=rv(c,co);return html`<span key=${co} className=${'lchip '+(r?r.status==='approved'?'go':'stop':'mute')} style=${{'--co':coColor(co)}}>${coShort(co)} ${r?r.status==='approved'?'✓':'✕':'รอตรวจ'}</span>`})}</div></div>
      <div className="row">${c.file_path?html`<${Img} path=${c.file_path}/>`:null}
      ${isSCG()&&canApproveWorkers()&&S.co&&S.co!=='all'?html`<${Btn} small=${true} kind="go" onClick=${()=>act(()=>rpc('review_cert',{p_co:S.co,p_cert:c.id,p_approve:true,p_note:null}),'รับรองแล้ว')}>รับรอง</${Btn}><${Btn} small=${true} kind="danger" onClick=${()=>act(()=>rpc('review_cert',{p_co:S.co,p_cert:c.id,p_approve:false,p_note:'เอกสารไม่ถูกต้อง'}),'บันทึกแล้ว')}>ไม่ผ่าน</${Btn}>`:null}</div></div>`):html`<div className="sm muted">ยังไม่มี</div>`}
    ${isSafety()&&w.selfdec_status==='doctor_submitted'?html`<${Card} pad=${true} className="col tight"><b>ใบรับรองแพทย์ (Self-declaration)</b><div className="sm muted">Safety เห็นเฉพาะใบรับรองแพทย์ ไม่เห็นคำตอบรายข้อ</div><${Img} path=${w.selfdec_doctor_path} bucket="health" cls="thumb lg"/>
      <div className="row"><${Btn} kind="danger" onClick=${()=>act(()=>rpc('review_selfdec_doctor',{p_worker:id,p_ok:false,p_note:'ใบรับรองไม่ครอบคลุมงานที่สูง'}),'บันทึกแล้ว')}>ไม่รับรอง</${Btn}><${Btn} kind="go" onClick=${()=>act(()=>rpc('review_selfdec_doctor',{p_worker:id,p_ok:true,p_note:null}),'รับรองแล้ว')}>รับรอง ให้ขึ้นที่สูงได้</${Btn}></div></${Card}>`:null}
  </${Sheet}>`}
function SelfdecSheet({id}){useStore();const w=byId(S.workers,id);const items=(sett('selfdec',null)||{}).items||[];const prev=(S.selfdec.find(x=>x.worker_id===id)||{}).answers||{};const [a,setA]=useState(prev);const [doc,setDoc]=useState(null);const [sig,setSig]=useState(false);
  const all=items.every((_,i)=>a[i+1]);
  return html`<${Sheet} title=${'Self-declaration · '+w.full_name} sub="แบบประเมินสุขภาพตนเองก่อนทำงานบนที่สูง ปีละครั้ง · คำตอบเห็นเฉพาะผู้ดูแลบริษัทคุณ"
    foot=${html`<${Btn} kind="primary" block=${true} disabled=${!all||!sig} onClick=${async()=>{const r=await act(()=>rpc('submit_selfdec',{p_worker:id,p_answers:a}));if(r)UI.toast(r==='ok'?'ผ่าน ใช้ได้ 1 ปี':'มีข้อที่ตอบ "เคย/มี" ต้องแนบใบรับรองแพทย์')}}>บันทึก</${Btn}>`}>
    <${Banner} kind="info">อ่านให้ช่างฟังทีละข้อในภาษาของช่าง แล้วเลือกคำตอบ · ตอบ "เคย/มี" ข้อใด ต้องมีใบรับรองแพทย์ก่อนขึ้นที่สูง</${Banner}>
    ${items.map((t,i)=>html`<div key=${i} className="qrow"><span className="num xs muted" style=${{width:22}}>${i+1}</span><span className="grow">${t}</span><${Seg} v=${a[i+1]} set=${v=>setA(o=>({...o,[i+1]:v}))} opts=${[['no','ไม่เคย'],['yes','เคย/มี']]}/></div>`)}
    <${Check} on=${sig} set=${setSig}>ช่างยืนยันว่าคำตอบเป็นความจริง (ลงชื่อโดยผู้ดูแลบริษัทแทนช่าง)</${Check}>
    ${['need_doctor','doctor_submitted'].includes(w.selfdec_status)?html`<${Card} pad=${true} className="col tight"><b>ใบรับรองแพทย์</b>
      <${Upload} label="แนบใบรับรองแพทย์ (ระบุว่าทำงานบนที่สูงได้)" bucket="health" value=${doc||w.selfdec_doctor_path} onChange=${setDoc}/>
      <${Btn} kind="dark" disabled=${!doc} onClick=${()=>act(()=>rpc('submit_selfdec_doctor',{p_worker:id,p_path:doc}),'ส่งให้ Safety รับรองแล้ว')}>ส่งให้ Safety รับรอง</${Btn}></${Card}>`:null}
  </${Sheet}>`}
function CertEdit({worker}){const [f,setF]=useState({cert_type:'induction',issued_on:'',expires_on:'',file_path:null});const set=k=>v=>setF(o=>({...o,[k]:v}));
  return html`<${Sheet} title="เพิ่ม cert / ผลตรวจสุขภาพ" foot=${html`<${Btn} kind="primary" block=${true} disabled=${!f.file_path} onClick=${()=>act(async()=>{const {error}=await sb.from('worker_certs').insert({...f,worker_id:worker,issued_on:f.issued_on||null,expires_on:f.expires_on||null});if(error)throw error;UI.close()},'ส่งให้ SCG ตรวจแล้ว')}>ส่งตรวจ</${Btn}>`}>
    <${Field} label="ประเภท"><${Sel} v=${f.cert_type} set=${set('cert_type')} opts=${Object.entries(sett('cert_types',null)||{})}/></${Field}>
    <div className="fgrid"><${Field} label="วันที่ออก"><${Inp} type="date" v=${f.issued_on} set=${set('issued_on')}/></${Field}><${Field} label="วันหมดอายุ" hint="อบรมที่สูงจากสถาบันภายนอกไม่มีวันหมดอายุ เว้นว่างได้"><${Inp} type="date" v=${f.expires_on} set=${set('expires_on')}/></${Field}></div>
    <${Upload} label="ไฟล์ใบรับรอง/ผลตรวจ" accept="image/*,application/pdf" value=${f.file_path} onChange=${set('file_path')}/>
    <div className="xs muted">ไฟล์เดียวใช้ร่วมทุกบริษัท SCG แต่ละบริษัทกดรับรองเอง</div></${Sheet}>`}
function TeamEdit({id}){useStore();const t=id?byId(S.teams,id):{};const [name,setName]=useState(t.name||'');const [lead,setLead]=useState(t.lead_id||'');const [mem,setMem]=useState(id?teamWorkers(id):[]);
  const leads=S.profiles.filter(p=>p.contractor_id===ME.contractor_id&&['team_lead','contractor_admin'].includes(p.role));
  const save=()=>act(async()=>{let tid=id;if(id){const r=await sb.from('teams').update({name,lead_id:lead||null}).eq('id',id);if(r.error)throw r.error}
    else{const r=await sb.from('teams').insert({name,lead_id:lead||null,contractor_id:ME.contractor_id}).select().single();if(r.error)throw r.error;tid=r.data.id}
    const d=await sb.from('team_members').delete().eq('team_id',tid);if(d.error)throw d.error;if(mem.length){const r=await sb.from('team_members').insert(mem.map(w=>({team_id:tid,worker_id:w})));if(r.error)throw r.error}UI.close()},'บันทึกทีมแล้ว');
  return html`<${Sheet} title=${id?'แก้ทีม':'สร้างทีม'} foot=${html`<${Btn} kind="primary" block=${true} disabled=${!name.trim()} onClick=${save}>บันทึก</${Btn}>`}>
    <${Field} label="ชื่อทีม"><${Inp} v=${name} set=${setName}/></${Field}>
    <${Field} label="หัวหน้าทีม (ผู้ใช้แอป)" hint="ยังไม่มีชื่อ? เชิญหัวหน้าทีมในแท็บ ผู้ใช้แอป"><${Sel} v=${lead} set=${setLead} opts=${[['','เลือก'],...leads.map(p=>[p.id,p.full_name||p.email])]}/></${Field}>
    <div className="eyebrow">สมาชิก (ทีมละ 4–6 คน)</div>${S.workers.filter(w=>w.contractor_id===ME.contractor_id).map(w=>html`<${Check} key=${w.id} on=${mem.includes(w.id)} set=${v=>setMem(o=>v?[...o,w.id]:o.filter(x=>x!==w.id))}>${w.full_name} <${LinkChips} w=${w}/></${Check}>`)}
  </${Sheet}>`}

/* ---------- บริษัทของฉัน (ผู้ดูแลบริษัทผู้รับเหมา) ---------- */
function CCompany(){useStore();const c=ctrOf(ME.contractor_id)||{};const [f,setF]=useState({name:c.name||'',contact_name:c.contact_name||'',contact_phone:c.contact_phone||'',email:c.email||'',address:c.address||'',safety_officer:c.safety_officer||''});
  const set=k=>v=>setF(o=>({...o,[k]:v}));const docs=S.docs.filter(d=>d.contractor_id===c.id);const DT=sett('doc_types',null)||{};
  return html`<div className="col">
    <${Card}><${CardH} icon="building" title="สถานะกับบริษัท SCG"/><div className="card-b col tight">${S.links.filter(l=>l.contractor_id===c.id).map(l=>html`<div key=${l.scg_company_id} className="between"><span className="row"><${CoBadge} id=${l.scg_company_id}/>${coName(l.scg_company_id)}</span><${Chip} c=${l.status==='approved'?'go':l.status==='pending'?'warn':'stop'} t=${l.status==='approved'?'อนุมัติให้รับงาน':l.status==='pending'?'รออนุมัติ':'ถูกพักรับงาน'}/></div>`)}</div></${Card}>
    <${Card}><${CardH} icon="doc" title="เอกสารบริษัท" sub="หมดอายุแล้วระบบพักรับงาน · เตือนล่วงหน้า 30 วัน"/><div className="card-b col tight">
      ${Object.entries(DT).filter(([k])=>k!=='other').map(([k,l])=>{const d=docs.filter(x=>x.doc_type===k).sort((a,b)=>(b.expires_on||'9999').localeCompare(a.expires_on||'9999'))[0];const exp=d&&d.expires_on&&d.expires_on<today();const soon=d&&d.expires_on&&d.expires_on<addDays(today(),30);
        return html`<div key=${k} className="between"><div className="grow sm"><b>${l}</b><div className="xs muted">${d?(d.expires_on?'หมดอายุ '+thD(d.expires_on):'ไม่มีวันหมดอายุ'):'ยังไม่ส่ง'}</div></div>${d?html`<${Img} path=${d.file_path}/>`:null}<${Chip} c=${!d||exp?'stop':soon?'warn':'go'} t=${!d?'ยังไม่ส่ง':exp?'หมดอายุ':soon?'ใกล้หมดอายุ':'ใช้ได้'}/>
          ${isCAdmin()?html`<${Btn} small=${true} onClick=${()=>UI.open(html`<${DocEdit} type=${k}/>`,l)}>อัปโหลด</${Btn}>`:null}</div>`})}</div></${Card}>
    <${Card} pad=${true} className="col"><b>ข้อมูลบริษัท</b><div className="fgrid"><${Field} label="ชื่อบริษัท"><${Inp} v=${f.name} set=${set('name')}/></${Field}><${Field} label="เลขผู้เสียภาษี"><input className="inp" value=${c.tax_id||''} disabled/></${Field}>
      <${Field} label="ผู้ติดต่อ"><${Inp} v=${f.contact_name} set=${set('contact_name')}/></${Field}><${Field} label="เบอร์โทร"><${Inp} v=${f.contact_phone} set=${set('contact_phone')}/></${Field}><${Field} label="อีเมลบริษัท"><${Inp} v=${f.email} set=${set('email')}/></${Field}>
      <${Field} label="จป. ตามกฎหมาย (ชื่อ / ระดับ)"><${Inp} v=${f.safety_officer} set=${set('safety_officer')}/></${Field}><${Field} label="ที่อยู่" span=${true}><${Inp} v=${f.address} set=${set('address')}/></${Field}></div>
      ${isCAdmin()?html`<${Btn} kind="primary" onClick=${()=>act(async()=>{const {error}=await sb.from('contractors').update(f).eq('id',c.id);if(error)throw error},'บันทึกแล้ว · แจ้งบริษัท SCG ที่เชื่อมอยู่')}>บันทึก</${Btn}>`:null}</${Card}></div>`}
function DocEdit({type}){const [p,setP]=useState(null);const [e,setE]=useState('');
  return html`<${Sheet} title="อัปโหลดเอกสาร" foot=${html`<${Btn} kind="primary" block=${true} disabled=${!p} onClick=${()=>act(async()=>{const {error}=await sb.from('contractor_docs').insert({contractor_id:ME.contractor_id,doc_type:type,file_path:p,expires_on:e||null,uploaded_by:ME.id});if(error)throw error;UI.close()},'บันทึกแล้ว')}>บันทึก</${Btn}>`}>
    <${Upload} label="ไฟล์เอกสาร" accept="image/*,application/pdf" value=${p} onChange=${setP}/><${Field} label="วันหมดอายุ (ถ้ามี)"><${Inp} type="date" v=${e} set=${setE}/></${Field}></${Sheet}>`}
