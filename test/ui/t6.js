// Induction เป็นเงื่อนไขก่อนอนุมัติช่าง · เช็กลิสต์คุณสมบัติ · Induction หมดอายุ = ขาดคุณสมบัติ
// ก่อนรัน: reset.sh แล้ว psql -c "update worker_certs set expires_on=bkk_today()-1 where worker_id='d1000000-0000-0000-0000-000000000002' and cert_type='induction'"
const {chromium,open}=require('./lib');
const bad=p=>p.errs.filter(e=>!/WebSocket|404/.test(e));
const must=(ok,msg)=>{if(!ok){console.log('FAIL',msg);process.exitCode=1}else console.log('ok',msg)};
(async()=>{const b=await chromium.launch();
  // Purchasing: ตรวจตัวบุคคลแล้ว แต่ Induction ยังไม่รับรอง → ปุ่มอนุมัติกดไม่ได้
  let p=await open(b,2);await p.waitForTimeout(2000);await p.click('.nav >> text=กล่องงาน');await p.waitForTimeout(600);
  must(await p.locator('text=ขาด อบรมความปลอดภัย SCG (Induction)').count()>0,'กล่องงานแสดง "ขาด Induction"');
  await p.click('text=นายบี ขยันดี');await p.waitForTimeout(800);await p.fill('.sheet input[placeholder^="เลขบัตร"]','1101700123456');await p.click('text=ยืนยันตัวบุคคล');await p.waitForTimeout(1200);
  const btn=p.locator('.sheet button',{hasText:'อนุมัติให้เข้าทำงาน'});
  must(await btn.isDisabled(),'ปุ่มอนุมัติกดไม่ได้เมื่อยังไม่มี Induction ที่รับรอง');
  must(await p.locator('.sheet >> text=รอ SCG').count()>0,'เช็กลิสต์บอกว่า Induction รอ SCG รับรอง');
  await p.screenshot({path:'/tmp/w/i_blocked.png'});
  // รับรอง Induction แล้วปุ่มอนุมัติกดได้
  await p.locator('.sheet .card',{hasText:'อบรมความปลอดภัย SCG (Induction)'}).last().locator('button',{hasText:/^รับรอง$/}).click();await p.waitForTimeout(1200);
  must(!(await btn.isDisabled()),'รับรอง Induction แล้วปุ่มอนุมัติกดได้');
  await btn.click();await p.waitForTimeout(1000);console.log('toast:',await p.locator('.toast').innerText().catch(()=>'-'));
  await p.screenshot({path:'/tmp/w/i_approved.png'});console.log('P errs',bad(p));await p.context().close();
  // ผู้ดูแลบริษัทผู้รับเหมา: ช่างที่ Induction หมดอายุ = ขาดคุณสมบัติ + เห็นสิ่งที่ต้องเติม
  p=await open(b,5);await p.waitForTimeout(1500);await p.click('text=ทุกบริษัท').catch(()=>{});await p.waitForTimeout(1000);
  await p.click('.nav >> text=ทีมและช่าง');await p.waitForTimeout(600);
  await p.click('text=นายแดง ใจสู้');await p.waitForTimeout(800);
  must(await p.locator('.sheet >> text=ขาดคุณสมบัติ').count()>0,'ช่าง Induction หมดอายุขึ้น "ขาดคุณสมบัติ"');
  must(await p.locator('.sheet >> text=หมดอายุแล้ว · อบรมใหม่').count()>0,'เช็กลิสต์บอกให้อบรมใหม่');
  await p.screenshot({path:'/tmp/w/i_lacking.png',fullPage:true});console.log('C errs',bad(p));await p.context().close();
  await b.close()})();
