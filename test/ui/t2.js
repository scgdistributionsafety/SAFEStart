// หัวหน้าทีม check-in งานหลังคาจนได้บัตรเขียว
const {chromium,open,jpg}=require('./lib');
const up=async(p,i)=>{const f=p.locator('.sheet input[type=file]').nth(i);await f.setInputFiles({name:'a.jpg',mimeType:'image/jpeg',buffer:jpg});await p.waitForTimeout(500)};
(async()=>{const b=await chromium.launch();const p=await open(b,6,{mobile:true,ls:{'ss.co.a0000000-0000-0000-0000-000000000006':'' }});
  await p.waitForTimeout(1200);await p.click('text=SCG Home Experience');await p.waitForTimeout(1200);
  await p.click('text=เริ่ม Safety Check-in');await p.waitForTimeout(800);
  const next=async n=>{await p.screenshot({path:'/tmp/w/c'+n+'.png'});const e=await p.locator('.sheet-f .xs').allInnerTexts();if(e.length)console.log('step',n,'err:',e.join());await p.click('text=ถัดไป ›')};
  await p.click('text=หาตำแหน่งปัจจุบัน');await p.waitForTimeout(600);await p.click('text=รับทราบและจัดการแล้ว');await next(0);
  await up(p,0);for(const n of ['นายเอก','นายแดง','Mr. Aung']){await p.locator('.sheet .checkrow',{hasText:n}).last().click()}
  await p.waitForTimeout(300);await next(1);
  const hs=await p.locator('.sheet .card').count();console.log('health cards',hs);
  for(let i=0;i<3;i++){const c=p.locator('.sheet .card').nth(i);const ins=c.locator('input.inp');await ins.nth(0).fill('80');await ins.nth(1).fill('120');await ins.nth(2).fill('80');await ins.nth(3).fill('0');
    await c.locator('input[type=file]').setInputFiles({name:'h.jpg',mimeType:'image/jpeg',buffer:jpg});await p.waitForTimeout(400)}
  await next(2);
  for(const r of await p.locator('.sheet .checkrow').all())await r.click();await next(3);
  for(let s=4;s<12;s++){const done=await p.locator('text=ส่ง Check-in').count();if(done)break;for(const btn of await p.locator('.sheet .pfn button.p').all())await btn.click();await next(s)}
  await up(p,0);await p.screenshot({path:'/tmp/w/c_final.png'});await p.click('text=ส่ง Check-in');await p.waitForTimeout(1500);
  await p.screenshot({path:'/tmp/w/c_pass.png'});console.log(await p.locator('.pass2').innerText().catch(()=>'no pass'));
  await up(p,0);await up(p,1);await p.click('text=ส่งรูป → บัตรเขียว');await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/c_green.png'});
  console.log(await p.locator('.pass2 h1').innerText().catch(()=>'?'));console.log(p.errs.filter(e=>!/WebSocket/.test(e)).join('\n'));await b.close()})();
