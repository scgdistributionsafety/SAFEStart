const crypto=require('crypto');const {chromium,devices}=require('/opt/node-tools/node_modules/playwright');
const SECRET='test-secret-test-secret-test-secret-123';
const b64=o=>Buffer.from(JSON.stringify(o)).toString('base64url');
function jwt(sub,email){const h=b64({alg:'HS256',typ:'JWT'});const now=Math.floor(Date.now()/1000);const p=b64({sub,email,role:'authenticated',aud:'authenticated',exp:now+36000,iat:now});
  return h+'.'+p+'.'+crypto.createHmac('sha256',SECRET).update(h+'.'+p).digest('base64url')}
const U=n=>'a0000000-0000-0000-0000-0000000000'+String(n).padStart(2,'0');
const EMAIL={1:'safety@demo.scg',2:'purchase@demo.scg',3:'ic@demo.scg',4:'icqc@demo.scg',5:'boss@changdee.co.th',6:'somchai@changdee.co.th',7:'ic.d@demo.scg',8:'purchase.d@demo.scg',9:'exec@demo.scg',10:'m@premierroof.co.th',11:'lead@premierroof.co.th',12:'msm@demo.scg'};
async function open(browser,n,{mobile,ls,base}={}){
  const ctx=await browser.newContext({...(mobile?devices['Pixel 7']:{viewport:{width:1360,height:900}}),geolocation:{latitude:13.6673,longitude:100.6502},permissions:['geolocation'],locale:'th-TH',timezoneId:'Asia/Bangkok'});
  const tok=jwt(U(n),EMAIL[n]);const now=Math.floor(Date.now()/1000);
  const sess={access_token:tok,token_type:'bearer',expires_in:36000,expires_at:now+36000,refresh_token:'x',user:{id:U(n),email:EMAIL[n],aud:'authenticated',role:'authenticated',app_metadata:{},user_metadata:{}}};
  await ctx.addInitScript(([s,extra])=>{localStorage.setItem('sb-localhost-auth-token',JSON.stringify(s));localStorage.setItem('ss.installed','1');for(const k in extra)localStorage.setItem(k,JSON.stringify(extra[k]))},[sess,ls||{}]);
  await ctx.route(/open-meteo/,r=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(fakeWx())}));
  await ctx.route(/tile\.openstreetmap/,r=>r.fulfill({status:200,contentType:'image/png',body:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mN8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==','base64')}));
  const M='/tmp/w/node_modules/';const fs=require('fs');
  const LIB=[[/react\.production\.min\.js/,M+'react/umd/react.production.min.js'],[/react-dom\.production\.min\.js/,M+'react-dom/umd/react-dom.production.min.js'],[/htm\.umd\.js/,M+'htm/dist/htm.umd.js'],
    [/supabase\.min\.js/,M+'@supabase/supabase-js/dist/umd/supabase.js'],[/qrcode\.min\.js/,M+'qrcode-generator/qrcode.js'],[/leaflet\.min\.js/,M+'leaflet/dist/leaflet.js'],[/leaflet\.min\.css/,M+'leaflet/dist/leaflet.css'],
    [/xlsx\.full\.min\.js/,M+'xlsx/dist/xlsx.full.min.js'],[/jsQR\.min\.js/,M+'jsqr/dist/jsQR.js']];
  await ctx.route(/cdnjs|jsdelivr|fonts\.g/,r=>{const u=r.request().url();const m=LIB.find(([re])=>re.test(u));if(m)return r.fulfill({status:200,contentType:/css$/.test(m[1])?'text/css':'text/javascript',body:fs.readFileSync(m[1])});return r.fulfill({status:200,contentType:'text/css',body:''})});
  const page=await ctx.newPage();page.errs=[];page.on('pageerror',e=>page.errs.push('PAGEERR '+e.message));page.on('console',m=>{if(m.type()==='error')page.errs.push(m.text())});
  page.on('dialog',d=>d.accept());
  await page.goto((base||'http://localhost:8080')+'/');return page}
function fakeWx(){const d=new Date();const ds=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');const time=[],t=[],rh=[],pp=[],pr=[],gu=[],wc=[];
  for(let h=0;h<48;h++){const day=h<24?ds:'x';time.push((h<24?ds:'2099-01-01')+'T'+String(h%24).padStart(2,'0')+':00');t.push(33);rh.push(55);pp.push(h%24>=13&&h%24<=15?75:20);pr.push(h%24===14?2:0);gu.push(h%24===13?44:18);wc.push(h%24===14?95:2)}
  return [{hourly:{time,temperature_2m:t,relative_humidity_2m:rh,precipitation_probability:pp,precipitation:pr,wind_gusts_10m:gu,weather_code:wc}}]}
const jpg=Buffer.from('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=','base64');
module.exports={chromium,open,jwt,U,jpg};
