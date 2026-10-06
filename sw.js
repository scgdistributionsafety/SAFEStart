/* SafeStart · Service worker: เปิดได้แม้สัญญาณหลุด + รับแจ้งเตือนบนเครื่อง */
const V='ss-v2-1';const SHELL=['./','index.html','style.css','config.js','ui.js','data.js','views_c.js','views_s.js','main.js','icon.svg','manifest.webmanifest'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{const u=new URL(e.request.url);if(e.request.method!=='GET')return;
  if(u.origin===location.origin){e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(V).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match(e.request).then(r=>r||caches.match('index.html'))));return}
  if(/cdnjs|jsdelivr|fonts\.(googleapis|gstatic)/.test(u.host))e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(x=>{const c=x.clone();caches.open(V).then(k=>k.put(e.request,c));return x})))});
self.addEventListener('push',e=>{let d={};try{d=e.data.json()}catch(_){d={title:'SafeStart',body:e.data&&e.data.text()}}
  e.waitUntil(self.registration.showNotification(d.title||'SafeStart',{body:d.body||'',icon:'icon-192.png',badge:'icon-192.png',tag:d.tag,renotify:!!d.urgent,requireInteraction:!!d.urgent,data:{url:d.url||'./'}}))});
self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(clients.matchAll({type:'window'}).then(ws=>{const w=ws.find(x=>'focus' in x);return w?w.focus():clients.openWindow(e.notification.data.url)}))});
