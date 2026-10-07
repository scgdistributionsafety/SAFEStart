const {chromium,open,jpg}=require('./lib');const B='http://localhost:8090';
const role=async(p,name)=>{await p.waitForSelector('.whob:not([disabled])',{timeout:20000});await p.click('.whob >> text='+name);await p.waitForTimeout(1200)};
const up=async(p,i)=>{await p.locator('.sheet input[type=file]').nth(i).setInputFiles({name:'a.jpg',mimeType:'image/jpeg',buffer:jpg});await p.waitForTimeout(300)};
(async()=>{const b=await chromium.launch();let p=await open(b,6,{mobile:true,base:B});await role(p,'หัวหน้าทีมช่าง');await p.click('text=SCG Home Experience');await p.waitForTimeout(800);
  await p.click('text=เริ่ม Safety Check-in');await p.waitForTimeout(500);const next=async()=>{const e=await p.locator('.sheet-f .xs').allInnerTexts();if(e.length)console.log('err:',e.join());await p.click('text=ถัดไป ›')};
  await p.click('text=หาตำแหน่งปัจจุบัน');await p.waitForTimeout(500);await p.click('text=รับทราบและจัดการแล้ว');await next();
  await p.click('text=ใช้รูปตัวอย่าง (เดโม)');for(const n of ['นายเอก','นายแดง','Mr. Aung']){await p.locator('.sheet .checkrow',{hasText:n}).last().click()}await next();
  for(let i=0;i<3;i++){const c=p.locator('.sheet .card').nth(i);const ins=c.locator('input.inp');await ins.nth(0).fill('80');await ins.nth(1).fill('120');await ins.nth(2).fill('80');await ins.nth(3).fill('0');await c.locator('text=ใช้รูปตัวอย่าง (เดโม)').click()}
  await next();for(const r of await p.locator('.sheet .checkrow').all())await r.click();await next();
  for(let s=0;s<9;s++){if(await p.locator('text=ส่ง Check-in').count())break;for(const btn of await p.locator('.sheet .pfn button.p').all())await btn.click();await next()}
  await p.click('text=ใช้รูปตัวอย่าง (เดโม)');await p.click('text=ส่ง Check-in');await p.waitForTimeout(1200);
  while(await p.locator('text=ใช้รูปตัวอย่าง (เดโม)').count()){await p.locator('text=ใช้รูปตัวอย่าง (เดโม)').first().click();await p.waitForTimeout(150)}
  await p.screenshot({path:'/tmp/w/f_orange.png'});await p.click('text=ส่งรูป → บัตรเขียว');await p.waitForTimeout(1000);console.log('pass:',await p.locator('.pass2 h1').innerText());
  await p.keyboard.press('Escape');await p.waitForTimeout(300);
  // SOS
  const sos=p.locator('.sos');const bb=await sos.boundingBox();await p.mouse.move(bb.x+20,bb.y+10);await p.mouse.down();await p.waitForTimeout(1300);await p.mouse.up();await p.waitForTimeout(1000);
  await p.screenshot({path:'/tmp/w/f_sos.png'});console.log('sos:',(await p.locator('.sheet h2').allInnerTexts()).join());
  console.log('errs',p.errs.filter(e=>!/WebSocket|404|tile/.test(e)));await p.context().close();
  // IC เห็นเหตุ SOS ในกล่องงาน (ฐานข้อมูลเดียวกันในหน้าเดียว ต้องอยู่หน้าเดิม) -> สลับบทบาทในหน้าเดิมไม่ได้หลังปิด context จึงทดสอบแยก
  p=await open(b,3,{base:B});await role(p,'Installation Consultant');await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/f_board.png'});
  await p.click('.nav >> text=กล่องงาน');await p.waitForTimeout(500);await p.click('text=PO-24004 · หลังคาใหม่/Garage');await p.locator('.sheet button',{hasText:/^อนุมัติ$/}).click();await p.waitForTimeout(800);
  console.log('ic:',await p.locator('.toast').innerText().catch(()=>'-'));
  await p.keyboard.press('Escape');await p.waitForTimeout(400);await p.click('.demo-pill button');await p.click('.demo-pill >> text=ผู้ดูแลบริษัทผู้รับเหมา');await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/f_admin_pick.png'});
  await p.click('text=ทุกบริษัท');await p.waitForTimeout(1000);console.log('admin bell:',await p.locator('.topbar .dotn').innerText().catch(()=>'0'));
  await p.click('.demo-pill button');await p.click('.demo-pill >> text=หัวหน้าทีม (เข้าครั้งแรก)');await p.waitForTimeout(1200);await p.screenshot({path:'/tmp/w/f_pdpa.png'});
  console.log('errs',p.errs.filter(e=>!/WebSocket|404|tile/.test(e)));await b.close()})();
