# SafeStart — คำสั่งประจำโปรเจกต์สำหรับ Claude

เว็บแอปความปลอดภัยผู้รับเหมางานติดตั้งของ SCG (หลายบริษัท: SCG Distribution, SCG Home Experience) · เจ้าของงาน: Safety Officer SCG Distribution (ไม่ใช่โปรแกรมเมอร์ — อธิบายเป็นภาษาไทย ทีละขั้น ไม่ใช้ศัพท์เทคนิคโดยไม่จำเป็น)

## โครงสร้าง repo
| ที่อยู่ | คืออะไร |
|---|---|
| `/` (root) | **หน้าเว็บที่ใช้งานจริง** ผ่าน GitHub Pages → https://scgdistributionsafety.github.io/SAFEStart/ · push เข้า `main` = ขึ้นเว็บจริงภายใน 1–2 นาที |
| `config.js` | ค่าเชื่อม Supabase ของระบบจริง (URL + anon key ซึ่งเปิดเผยได้) · **ห้ามแก้/ห้ามทับ** เว้นแต่ผู้ใช้สั่ง |
| `supabase/src/01_tables.sql` `02_rpc.sql` `03_ops.sql` | ฐานข้อมูล: ตาราง, RLS, ฟังก์ชัน RPC, งานตั้งเวลา · `supabase/build.sh` รวมเป็น `schema.sql` + สร้าง `seed.sql` จาก `gen_seed.py` |
| `supabase/install_all.sql` | ติดตั้งใหม่ทั้งหมด (ล้างของเดิม!) · ใช้ตอนตั้งระบบครั้งแรกเท่านั้น |
| `supabase/migrations/` | ไฟล์แก้ฐานข้อมูลระบบจริงทีละครั้ง (ดูกติกาด้านล่าง) |
| `apps-script/Code.gs` | Google Apps Script: ส่งต่อเรื่องทุก 5 นาที, เตือน 07:00/08:30–11:00/18:30, สรุปเที่ยง, LINE webhook |
| `edge/push/index.ts` | Supabase Edge Function ส่ง Web Push |
| `test/` | ชุดทดสอบ: `scenario.sql` (กติกา 18 สถานการณ์บน Postgres 16 + PostgREST) · `test/ui/` Playwright |
| `demo/` | สร้างเดโม Postgres-ในเบราว์เซอร์ (PGlite) จากโค้ดจริง |
| `docs/SETUP.md` | คู่มือติดตั้ง · `docs/BACKLOG.md` รายการค้าง/คำขอผู้ใช้ · `docs/STATUS.md` ทำถึงไหนแล้ว |

## สถาปัตยกรรม
- **หน้าเว็บ:** React 18 UMD + `htm` ไม่มีขั้นตอน build (แก้ไฟล์ .js ตรง ๆ) · `ui.js` (ไอคอน, Sheet, Upload + ประทับเวลา/สถานที่, เสียงอ่าน 4 ภาษา) · `data.js` (store `S`, `loadAll`, `jobState`, `workerBlockers`, สภาพอากาศ Open-Meteo) · `views_c.js` (ผู้รับเหมา) · `views_s.js` (SCG) · `main.js` (เข้าระบบ OTP, PDPA, เมนู, App) · `sw.js` PWA
- **Backend:** Supabase (Postgres + RLS + Auth OTP อีเมล + Storage `photos`/`idcheck`/`health` + Realtime) · การเขียนข้อมูลสำคัญผ่าน RPC `SECURITY DEFINER` เท่านั้น (ถอนสิทธิ์เขียนตรงเกือบทุกตาราง)
- **หลายบริษัท:** scg_companies → install_groups → projects → jobs · `contractors` ใช้ร่วม, `contractor_links` แยกบริษัท · `workers` ใช้ร่วม, `worker_links` (+โทษแบน) แยกบริษัท · `cert_reviews` แยกบริษัท · `lsr_flags` เห็นข้ามบริษัท · `settings` ค่ากลาง + ค่าเฉพาะบริษัท
- **ระดับความเสี่ยง:** สูง (ที่สูง/ไฟฟ้า/งานร้อน/อับอากาศ) IC โครงการอนุมัติ · กลาง (ยกของ/ขุด/สารเคมี) ผู้รับเหมาอนุมัติเอง + แจ้ง IC · ต่ำ อนุมัติอัตโนมัติ
- **บัตรผ่าน 2 ขั้น:** ส้ม (ติดตั้งจุดยึด) → เขียว หลังส่งรูปภายใน 60 นาที
- **Fit-to-Work:** ตรวจสุขภาพรายวัน (ชีพจร 60–100, ความดัน 90–140/60–90, แอลกอฮอล์ 0) · Self-declaration 22 ข้อ อายุ 365 วัน · Buddy ≥ 2 คนบนที่สูง · อายุ ≥ 18

## กติกาที่ห้ามละเมิด
1. **คีย์ลับ:** service_role / Secret key อยู่ใน Apps Script (Script properties) ที่เดียว · ห้ามใส่ในไฟล์ใดใน repo (repo เป็น public) · ก่อน commit ให้ค้นหา `eyJ` `sb_secret_` — `config.js` มีได้เฉพาะ anon key
2. **ข้อมูลส่วนบุคคล:** ห้าม commit อีเมลจริง/ชื่อจริง/เลขบัตร · ไฟล์ seed ใช้ `CHANGE_ME@scg.com`
3. **บัตรประชาชน:** ไม่เก็บสำเนา — รูปบัตรลบทันทีหลังตรวจ เก็บเฉพาะเลขท้าย 4 หลัก + HMAC (`app_secrets.id_salt`)
4. **สุขภาพ:** ค่าตรวจสุขภาพเห็นเฉพาะผู้ดูแลบริษัทผู้รับเหมาและ Safety · คำตอบ Self-declaration รายข้อ Safety ห้ามเห็น (เห็นเฉพาะใบแพทย์ + สถานะ)
5. **ฐานข้อมูลระบบจริง:** Claude รัน SQL บนระบบจริงไม่ได้ · ทุกการแก้ฐานข้อมูล ให้ (ก) แก้ใน `supabase/src/` (ข) สร้างไฟล์ `supabase/migrations/YYYY-MM-DD-ชื่อ.sql` ที่รันซ้ำได้ปลอดภัย (`create or replace`, `drop policy if exists`) และไม่ลบข้อมูล (ค) บอกผู้ใช้ให้วางรันใน Supabase › SQL Editor ทีละไฟล์ — **ห้ามสั่งให้รัน install_all.sql/reset.sql กับระบบจริง**
6. **Apps Script:** แก้ `apps-script/Code.gs` แล้วต้องบอกผู้ใช้ให้คัดลอกไปวางใน script.google.com เอง (ไม่ sync อัตโนมัติ)
7. **ภาษา:** ข้อความในแอปเป็นภาษาไทย (เช็กลิสต์มีเมียนมา/เขมร/ลาว) · ปุ่มและข้อความใช้คำง่าย
8. **ก่อน push เข้า main** (= ขึ้นเว็บจริง): ทดสอบ syntax (`node --check *.js`), ถ้าแก้ SQL ให้รัน `test/scenario.sql` บน Postgres ทดสอบ · งานใหญ่ให้ทำ branch + Pull Request ให้ผู้ใช้กด Merge

## ทดสอบในเครื่อง (ถ้ามี Postgres 16 + PostgREST)
`sh supabase/build.sh` → `sh test/reset.sh` → `psql ... -f test/scenario.sql` ต้องขึ้น `ALL TESTS PASSED` · หน้าเว็บ: `sh test/ui/sync.sh` แล้วรัน `test/ui/t*.js` (Playwright)

## งานถัดไป
ดู `docs/STATUS.md` และหัวข้อ "ต้องทำในรอบอัปเดตถัดไป" ใน `docs/BACKLOG.md`
