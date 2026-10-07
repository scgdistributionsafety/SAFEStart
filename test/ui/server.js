// เซิร์ฟเวอร์ทดสอบ: เสิร์ฟหน้าเว็บ + ส่งต่อ /rest/v1 ไป PostgREST + จำลอง storage/auth
const http=require('http'),fs=require('fs'),path=require('path');
const WEB=process.argv[2]||path.join(__dirname,'../../web');const PORT=+process.argv[3]||8080;const store={};
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.webmanifest':'application/manifest+json'};
http.createServer((req,res)=>{const u=new URL(req.url,'http://x');
  const cors={'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-allow-methods':'*','access-control-expose-headers':'*'};
  if(req.method==='OPTIONS'){res.writeHead(204,cors);return res.end()}
  if(u.pathname.startsWith('/rest/v1/')){const p=http.request({host:'127.0.0.1',port:3001,path:req.url.replace('/rest/v1',''),method:req.method,headers:{...req.headers,host:'127.0.0.1:3001'}},r=>{res.writeHead(r.statusCode,{...r.headers,...cors});r.pipe(res)});req.pipe(p);p.on('error',e=>{res.writeHead(502);res.end(String(e))});return}
  if(u.pathname.startsWith('/storage/v1/object/sign/')){let b='';req.on('data',d=>b+=d);req.on('end',()=>{const k=u.pathname.replace('/storage/v1/object/sign/','');res.writeHead(200,{...cors,'content-type':'application/json'});res.end(JSON.stringify({signedURL:'/storage/v1/object/get/'+k+'?token=x'}))});return}
  if(u.pathname.startsWith('/storage/v1/object/get/')){const k=decodeURIComponent(u.pathname.replace('/storage/v1/object/get/',''));const v=store[k];
    if(v){res.writeHead(200,{...cors,'content-type':v.t});return res.end(v.b)}
    res.writeHead(200,{...cors,'content-type':'image/svg+xml'});return res.end('<svg xmlns="http://www.w3.org/2000/svg" width="320" height="200"><rect width="320" height="200" fill="#3C7D5C"/><text x="16" y="110" fill="#fff" font-size="16">'+k.split('/').pop()+'</text></svg>')}
  if(u.pathname.startsWith('/storage/v1/object/')){const chunks=[];req.on('data',d=>chunks.push(d));req.on('end',()=>{const k=decodeURIComponent(u.pathname.replace('/storage/v1/object/',''));
    if(req.method==='DELETE'||req.method==='POST'&&k===''){res.writeHead(200,{...cors,'content-type':'application/json'});return res.end('[]')}
    store[k]={b:Buffer.concat(chunks),t:req.headers['content-type']||'image/jpeg'};res.writeHead(200,{...cors,'content-type':'application/json'});res.end(JSON.stringify({Key:k}))});return}
  if(u.pathname.startsWith('/auth/v1/')){res.writeHead(200,{...cors,'content-type':'application/json'});return res.end('{}')}
  if(u.pathname.startsWith('/realtime/')){res.writeHead(404);return res.end()}
  let f=path.join(WEB,decodeURIComponent(u.pathname));if(u.pathname==='/'||fs.existsSync(f)&&fs.statSync(f).isDirectory())f=path.join(f,'index.html');
  if(!fs.existsSync(f)){res.writeHead(404);return res.end('nf')}
  res.writeHead(200,{'content-type':types[path.extname(f)]||'application/octet-stream','cache-control':'no-store'});fs.createReadStream(f).pipe(res);
}).listen(PORT,()=>console.log('ui server',PORT));
