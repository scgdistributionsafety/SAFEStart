// SafeStart · เดโม: แทน Supabase ด้วย Postgres จริงที่รันในเบราว์เซอร์ (PGlite)
// ใช้ schema.sql ตัวเดียวกับระบบจริง ดังนั้นกติกา สิทธิ์ (RLS) และฟังก์ชันทั้งหมดทำงานเหมือนของจริง
export function createDemoClient(dbPromise, {placeholder}={}){
  let CUR=null;const listeners=new Set();let meta=null;
  const ready=dbPromise.then(async db=>{
    const cols=await db.query(`select table_name t, column_name c, udt_name u from information_schema.columns where table_schema='public'`);
    const fns=await db.query(`select p.proname n, coalesce(p.proargnames,'{}') a, array(select format_type(x,null) from unnest(p.proargtypes) x) ty, format_type(p.prorettype,null) r from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public'`);
    meta={cols:{},fns:{}};cols.rows.forEach(r=>{(meta.cols[r.t]=meta.cols[r.t]||{})[r.c]=r.u});
    fns.rows.forEach(r=>{meta.fns[r.n]={args:r.a,types:r.ty,ret:r.r}});return db});
  const arr=a=>'{'+a.map(x=>x==null?'NULL':Array.isArray(x)?arr(x):'"'+String(x).replace(/\\/g,'\\\\').replace(/"/g,'\\"')+'"').join(',')+'}';
  const ser=(udt,v)=>{if(v==null)return null;if(udt==='jsonb'||udt==='json')return JSON.stringify(v);if(udt&&udt[0]==='_'&&Array.isArray(v))return arr(v);
    if(typeof v==='object'&&!(v instanceof Date))return JSON.stringify(v);return v};
  const q=s=>'"'+String(s).replace(/"/g,'""')+'"';
  async function run(fn){const db=await ready;const claims=JSON.stringify(CUR?{sub:CUR,role:'authenticated'}:{role:'anon'});
    return db.transaction(async tx=>{await tx.query(CUR?'set local role authenticated':'set local role anon');await tx.query(`select set_config('request.jwt.claims',$1,true)`,[claims]);return fn(tx)})}
  const msg=e=>({message:String(e&&e.message||e).replace(/^error:\s*/i,''),code:e&&e.code});

  class Q{constructor(t){this.t=t;this.op='select';this.fs=[];this.ps=[];this.ord=[];this.lim=null;this.one=false;this.ret=false}
    _c(c){return(meta&&meta.cols[this.t]||{})[c]}
    _f(c,op,v){this.fs.push([c,op,v]);return this}
    select(){if(this.op!=='select')this.ret=true;return this}
    eq(c,v){return this._f(c,'=',v)}neq(c,v){return this._f(c,'<>',v)}gt(c,v){return this._f(c,'>',v)}gte(c,v){return this._f(c,'>=',v)}lt(c,v){return this._f(c,'<',v)}lte(c,v){return this._f(c,'<=',v)}
    in(c,v){return this._f(c,'in',v)}is(c,v){return this._f(c,'is',v)}
    order(c,o){this.ord.push([c,!o||o.ascending!==false]);return this}limit(n){this.lim=n;return this}
    single(){this.one=true;return this}maybeSingle(){this.one=true;this.maybe=true;return this}
    insert(rows){this.op='insert';this.rows=Array.isArray(rows)?rows:[rows];return this}
    upsert(rows,o){this.op='upsert';this.rows=Array.isArray(rows)?rows:[rows];this.conf=o&&o.onConflict;return this}
    update(o){this.op='update';this.patch=o;return this}delete(){this.op='delete';return this}
    _where(ps){if(!this.fs.length)return'';return' where '+this.fs.map(([c,op,v])=>{
      if(op==='is')return q(c)+' is '+(v===null?'null':v?'true':'false');
      if(op==='in'){ps.push(arr(v));return q(c)+'=any($'+ps.length+'::'+(this._c(c)||'text')+'[])'}
      ps.push(ser(this._c(c),v));return q(c)+' '+op+' $'+ps.length+'::'+(this._c(c)||'text').replace(/^_(.*)$/,'$1[]')}).join(' and ')}
    async _exec(){await ready;const ps=[];let sql;const T=q(this.t);
      if(this.op==='select'){sql='select * from '+T+this._where(ps)+(this.ord.length?' order by '+this.ord.map(([c,a])=>q(c)+(a?' asc':' desc')).join(','):'')+(this.lim?' limit '+(+this.lim):'')}
      else if(this.op==='insert'||this.op==='upsert'){const cs=[...new Set(this.rows.flatMap(r=>Object.keys(r)))];
        const vals=this.rows.map(r=>'('+cs.map(c=>{if(!(c in r))return'default';ps.push(ser(this._c(c),r[c]));return'$'+ps.length}).join(',')+')').join(',');
        sql='insert into '+T+'('+cs.map(q).join(',')+') values '+vals;
        if(this.op==='upsert'){const k=(this.conf||'id').split(',').map(s=>s.trim());sql+=' on conflict ('+k.map(q).join(',')+') do update set '+cs.filter(c=>!k.includes(c)).map(c=>q(c)+'=excluded.'+q(c)).join(',')}
        sql+=' returning *'}
      else if(this.op==='update'){const sets=Object.keys(this.patch).map(c=>{ps.push(ser(this._c(c),this.patch[c]));return q(c)+'=$'+ps.length});sql='update '+T+' set '+sets.join(',')+this._where(ps)+' returning *'}
      else{sql='delete from '+T+this._where(ps)+' returning *'}
      try{const r=await run(tx=>tx.query(sql,ps));let d=r.rows;if(this.one){if(d.length!==1)return this.maybe&&!d.length?{data:null,error:null}:{data:null,error:{message:'ไม่พบข้อมูล หรือไม่มีสิทธิ์'}};d=d[0]}
        return{data:d,error:null}}catch(e){return{data:null,error:msg(e)}}}
    then(a,b){return this._exec().then(a,b)}}

  async function rpc(fn,args){await ready;const f=meta.fns[fn];if(!f)return{data:null,error:{message:'ไม่พบฟังก์ชัน '+fn}};const ps=[];
    const parts=Object.entries(args||{}).map(([k,v])=>{const i=f.args.indexOf(k);const ty=i>=0?f.types[i]:'text';
      ps.push(v==null?null:ty.endsWith('[]')?arr(v):(ty==='jsonb'||ty==='json')?JSON.stringify(v):v);return k+' => $'+ps.length+'::'+ty});
    try{const r=await run(tx=>tx.query('select public.'+fn+'('+parts.join(',')+') as r',ps));return{data:f.ret==='void'?null:r.rows[0].r,error:null}}catch(e){return{data:null,error:msg(e)}}}

  const BLOBS={};
  const storage={from:b=>({upload:async(p,body)=>{BLOBS[b+'/'+p]=URL.createObjectURL(body);return{data:{path:p},error:null}},
    createSignedUrl:async p=>({data:{signedUrl:BLOBS[b+'/'+p]||placeholder(p)},error:null}),remove:async()=>({data:[],error:null})})};
  const sess=()=>CUR?{access_token:'demo',user:{id:CUR}}:null;
  const auth={getSession:async()=>({data:{session:sess()},error:null}),onAuthStateChange:cb=>{listeners.add(cb);return{data:{subscription:{unsubscribe:()=>listeners.delete(cb)}}}},
    signInWithOtp:async()=>({error:null}),verifyOtp:async()=>({error:null}),signOut:async()=>{CUR=null;listeners.forEach(f=>f('SIGNED_OUT',null));window.DEMO_SWITCH&&window.DEMO_SWITCH(null);return{error:null}}};
  const client={from:t=>new Q(t),rpc,storage,auth,channel:()=>({on(){return this},subscribe(){return this}})};
  return{client,ready,setUser:id=>{CUR=id},query:async(s,p)=>(await ready).query(s,p)};
}
