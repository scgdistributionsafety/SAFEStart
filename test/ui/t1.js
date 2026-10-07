const {chromium,open,jpg}=require('./lib');
(async()=>{const b=await chromium.launch();
  const p=await open(b,6,{mobile:true});await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/s1.png'});
  await p.click('text=SCG Home Experience');await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/s2.png',fullPage:true});
  console.log(await p.evaluate(()=>document.body.innerText.slice(0,900)));console.log(p.errs.filter(e=>!/WebSocket/.test(e)).join('\n'));await b.close()})();
