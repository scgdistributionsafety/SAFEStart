const {chromium,open,jpg}=require('./lib');
(async()=>{const b=await chromium.launch();const p=await open(b,6,{mobile:true,base:'http://localhost:8090'});
  await p.waitForTimeout(6000);await p.screenshot({path:'/tmp/w/e0.png'});
  await p.click('text=หัวหน้าทีมช่าง');await p.waitForTimeout(1500);await p.click('text=SCG Home Experience');await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/e1.png'});
  console.log((await p.evaluate(()=>document.body.innerText)).slice(0,300));console.log(p.errs.filter(e=>!/WebSocket|404/.test(e)).join('\n'));await b.close()})();
