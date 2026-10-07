const {chromium,open}=require('./lib');
(async()=>{const b=await chromium.launch();const p=await open(b,6,{mobile:true,base:'http://localhost:8090'});
  await p.waitForTimeout(8000);console.log(await p.evaluate(()=>window.DEMO_PROGRESS));console.log(p.errs.join('\n'));await b.close()})();
