const {chromium,open,jpg}=require('./lib');
const bad=p=>p.errs.filter(e=>!/WebSocket|404/.test(e));
(async()=>{const b=await chromium.launch();
  // IC: กระดาน + อนุมัติใบอนุญาต
  let p=await open(b,3);await p.waitForTimeout(2000);await p.screenshot({path:'/tmp/w/d_board.png'});
  await p.click('.nav >> text=กล่องงาน');await p.waitForTimeout(800);await p.screenshot({path:'/tmp/w/d_inbox.png',fullPage:true});
  await p.click('text=PO-24004 · หลังคาใหม่/Garage');await p.waitForTimeout(800);await p.screenshot({path:'/tmp/w/d_job.png'});
  await p.locator('.sheet button',{hasText:/^อนุมัติ$/}).click();await p.waitForTimeout(1000);console.log('IC toast:',await p.locator('.toast').innerText().catch(()=>'-'));
  await p.keyboard.press('Escape');await p.waitForTimeout(400);
  await p.click('.nav >> text=สแกนบัตรผ่าน');await p.waitForTimeout(500);
  const tok=await p.evaluate(()=>S.checkins.find(c=>c.stage==='setup')?.pass_token);await p.fill('input.inp',tok||'x');await p.click('text=ตรวจ');await p.waitForTimeout(800);
  await p.screenshot({path:'/tmp/w/d_scan.png'});console.log('IC errs',bad(p));await p.context().close();
  // Purchasing: ตรวจตัวบุคคล + อนุมัติช่าง
  p=await open(b,2);await p.waitForTimeout(2000);await p.click('.nav >> text=กล่องงาน');await p.waitForTimeout(600);
  await p.click('text=นายบี ขยันดี');await p.waitForTimeout(800);await p.fill('.sheet input[placeholder^="เลขบัตร"]','1101700123456');await p.click('text=ยืนยันตัวบุคคล');await p.waitForTimeout(1000);
  await p.locator('.sheet .card',{hasText:'อบรมความปลอดภัย SCG (Induction)'}).last().locator('button',{hasText:/^รับรอง$/}).click();await p.waitForTimeout(1000);
  await p.click('text=อนุมัติให้เข้าทำงาน');await p.waitForTimeout(1000);await p.screenshot({path:'/tmp/w/d_worker.png'});console.log('P toast',await p.locator('.toast').innerText().catch(()=>'-'));
  await p.keyboard.press('Escape');await p.click('.nav >> text=ผู้รับเหมา');await p.waitForTimeout(600);await p.fill('input[placeholder^="เลขผู้เสียภาษี"]','0105562000033');await p.click('text=ค้นหา');await p.waitForTimeout(800);await p.screenshot({path:'/tmp/w/d_ctr.png'});
  await p.click('.nav >> text=แผนงาน/PO');await p.waitForTimeout(500);await p.click('text=นำเข้า PO จาก Excel');
  const X=require('/tmp/w/node_modules/xlsx');const ws=X.utils.aoa_to_sheet([['เลขที่ PO','หมู่บ้าน','Vendor','ประเภทงาน','วันที่ติดตั้ง','บ้านเลขที่'],['PO-50001','ม.ใหม่ ทดสอบ UI','V-1001','รางน้ำใหม่','2026-12-01','5/5']]);const wb=X.utils.book_new();X.utils.book_append_sheet(wb,ws,'s');
  await p.locator('input[type=file]').setInputFiles({name:'po.xlsx',mimeType:'application/octet-stream',buffer:X.write(wb,{type:'buffer',bookType:'xlsx'})});await p.waitForTimeout(800);
  await p.screenshot({path:'/tmp/w/d_po.png',fullPage:true});await p.click('text=/^นำเข้า 1 แถว/');await p.waitForTimeout(1000);console.log('PO toast',await p.locator('.toast').innerText().catch(()=>'-'));
  console.log('P errs',bad(p));await p.context().close();
  // Safety: ตั้งค่า
  p=await open(b,1);await p.waitForTimeout(1500);await p.screenshot({path:'/tmp/w/d_pick.png'});await p.click('text=SCG Home Experience');await p.waitForTimeout(1200);
  await p.click('.nav >> text=ตั้งค่า');await p.waitForTimeout(600);await p.click('.tabs >> text=ประเภทงาน');await p.waitForTimeout(400);await p.screenshot({path:'/tmp/w/d_set.png'});
  await p.click('.tabs >> text=กติกา/อากาศ');await p.waitForTimeout(300);await p.click('text=/^บันทึก$/');await p.waitForTimeout(600);console.log('S toast',await p.locator('.toast').innerText().catch(()=>'-'));
  console.log('S errs',bad(p));await p.context().close();
  // ผู้ดูแลบริษัท: ยื่นแผน + ทีม
  p=await open(b,5,{mobile:true});await p.waitForTimeout(1500);await p.click('text=ทุกบริษัท');await p.waitForTimeout(1000);
  await p.click('.bnav >> text=งาน');await p.waitForTimeout(500);await p.locator('.job-card',{hasText:'PO-D1002'}).locator('text=ยื่นแผนงาน').click();await p.waitForTimeout(600);
  await p.screenshot({path:'/tmp/w/m_plan.png',fullPage:false});await p.click('.sheet-f >> text=ยื่นแผนงาน');await p.waitForTimeout(1000);console.log('A toast',await p.locator('.toast').innerText().catch(()=>'-'));
  await p.click('.bnav >> text=เพิ่มเติม');await p.waitForTimeout(400);await p.click('.sheet >> text=ทีมและช่าง');await p.waitForTimeout(800);await p.screenshot({path:'/tmp/w/m_team.png',fullPage:true});
  await p.click('text=นายชัย กล้าหาญ');await p.waitForTimeout(600);await p.screenshot({path:'/tmp/w/m_worker.png'});
  console.log('A errs',bad(p));await b.close()})();
