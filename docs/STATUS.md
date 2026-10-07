# SafeStart · ทำถึงตรงไหนแล้ว (เริ่มต่อจากตรงนี้)

บันทึก 7 ต.ค. 2569 20:25 · รายการค้างทั้งหมดอยู่ที่ `claude/safestart-backlog.md`
**ย้ายงานโค้ดไปทำใน Claude Code (claude.ai/code)** ตั้งแต่ 7 ต.ค. · งานตั้งค่าที่ต้องกดตามทีละขั้น (LINE OA, Push) ทำในแชตใหม่ของ Project นี้

## สถานะตอนนี้
| ส่วน | สถานะ |
|---|---|
| ฐานข้อมูล Supabase (install_all.sql + แก้ policy w_read) | ✅ ใช้งานได้ |
| หน้าเว็บ https://scgdistributionsafety.github.io/SAFEStart/ | ✅ ใช้งานได้ |
| อีเมลรหัสเข้าระบบ (Gmail SMTP <Gmail กลางของทีม> · รหัส 6 หลัก · 100 ฉบับ/ชม. · Template Confirm signup + Magic Link) | ✅ |
| Google Apps Script "SafeStart Automation" (บัญชี <Gmail กลางของทีม> · Trigger 5 รายการ) | ✅ รันปกติ · 7 ต.ค. morning/missingCheckin รันสำเร็จแต่ไม่มีงานเข้าเงื่อนไข (ถูกต้อง) |
| ทดสอบครบวงจร 4 รอบ | ✅ ผ่าน 6 ต.ค. |
| ทดสอบอีเมลแจ้งเตือนด้วย SQL `select notify(...)` | ⬜ ยังไม่ได้ยืนยันผล |
| เชื่อม GitHub กับ Claude (แอป Claude ติดตั้งบน scgdistributionsafety · repo SAFEStart · ผู้ร่วมแก้ไข sarayutl) | ✅ 7 ต.ค. |
| นำโค้ดทั้งหมดเข้า repo + CLAUDE.md | ✅ 7 ต.ค. |
| LINE OA | ⬜ |
| แจ้งเตือนบนมือถือ (Push / VAPID) | ⬜ |

## ⚠️ เช็กก่อนเริ่ม
- [ ] อัป **ui.js + main.js** (ส่งให้ 6 ต.ค. 19:55) ขึ้น GitHub แล้วหรือยัง — ถ้ายัง ให้ Claude Code ใส่จาก zip ตอนนำเข้า
- [ ] ไฟล์สำรองโค้ด `safestart-source-2026-10-06.zip` (ส่งให้ 6 ต.ค. 21:40) — ใช้นำเข้า repo
- [ ] repo SAFEStart เป็น public (GitHub Pages) → ห้าม commit อีเมลจริง/คีย์ลับ · ไฟล์ seed ให้ใช้ CHANGE_ME@scg.com

## ขั้นต่อไป (เรียงลำดับ)
1. **เชื่อม GitHub ให้เสร็จ** → เปิด claude.ai/code เลือก repo scgdistributionsafety/SAFEStart
2. **งานแรกใน Claude Code: นำเข้าโค้ด** (ใช้ข้อความเริ่มต้นด้านล่าง)
3. **LINE OA** (~20 นาที · แชตใหม่ใน Project นี้) · เตรียมบัญชี LINE สมัคร OA ในนามทีม + ชื่อ OA
   - สร้าง OA → เปิด Messaging API → Channel access token ใส่ Apps Script property `LINE_TOKEN`
   - Deploy Apps Script เป็น Web app → URL ใส่ Webhook URL ใน LINE · ปิดข้อความตอบกลับอัตโนมัติ
   - ทดสอบ: หน้า "ฉัน" → ขอรหัส 6 ตัว → พิมพ์ในแชต OA → "ผูกบัญชีแล้ว"
4. **Push บนมือถือ** (~15 นาที) · web/tools/vapid.html → Edge Function `push` → PUSH_URL + PUSH_SECRET ใน Apps Script → public key ใน config.js
5. **รอบแก้โค้ดใน Claude Code**: รายการ "ต้องทำในรอบอัปเดตถัดไป" ใน backlog
6. (ไม่บังคับ) ทดสอบกรณีผิดปกติ: ตีกลับแผน · หยุด/ปลดล็อก · แจ้งเหตุ/SOS · Finding · LSR · PO-TEST-002

## ข้อมูลทดสอบที่มีในระบบ
- บริษัทผู้รับเหมา "บจ.ทดสอบการช่าง" (vendor T-001) อยู่ทั้ง SCGD และ SCGHE · แอดมิน = Gmail ส่วนตัวของผู้ใช้
- ช่าง: ทดสอบ หนึ่ง (ช่างหลังคา · ••3456) · ทดสอบ สอง (Foreman · ••3213) · อนุมัติ SCGHE + cert ครบ · ทีมหลังคา A
- งาน SCGHE: PO-TEST-001 Roof Renovate 6–10 ต.ค. (ปิดงาน) · PO-TEST-002 ทาสี/กันซึม/ห้องน้ำ 7–8 ต.ค. (ยังไม่ยื่นแผน)
- Safety: <อีเมล Safety admin> (owner + safety_admin ทุกบริษัท) · ฝั่งผู้รับเหมาทดสอบใน Incognito
- โครงการ "ม.ทดสอบ SafeStart" ยังไม่มี IC (Safety อนุมัติแทน)

## ข้อควรจำ (ความปลอดภัย)
- service_role / Secret key อยู่ใน Apps Script ที่เดียว · ห้ามส่งในแชต / ห้ามใส่ config.js / GitHub
- <Gmail กลางของทีม> ใช้ส่งอีเมลระบบเท่านั้น ไม่ใช่บัญชีผู้ใช้ในแอป
