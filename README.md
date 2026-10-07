# SAFEStart · ระบบความปลอดภัยผู้รับเหมางานติดตั้ง SCG

เว็บแอปเดียวสำหรับผู้รับเหมาและพนักงาน SCG หลายบริษัท: ยื่นแผนงาน · Safety Check-in (ตรวจสุขภาพ, Toolbox, เช็กลิสต์ภาพ 4 ภาษา) · บัตรผ่าน 2 ขั้น · ปิดงาน · แจ้งเหตุ/SOS · ทะเบียนช่างและ cert · กฎพิทักษ์ชีวิต (LSR)

- ใช้งาน: https://scgdistributionsafety.github.io/SAFEStart/
- ติดตั้ง: `docs/SETUP.md` · สถานะ: `docs/STATUS.md` · รายการค้าง: `docs/BACKLOG.md`
- โครงสร้างและกติกาการพัฒนา: `CLAUDE.md`

| โฟลเดอร์ | |
|---|---|
| (root) | หน้าเว็บ (ไม่ต้อง build) + PWA |
| `supabase/` | ฐานข้อมูล สิทธิ์ (RLS) ฟังก์ชัน ค่าตั้งต้น · `migrations/` ไฟล์แก้ระบบจริง |
| `apps-script/` | งานอัตโนมัติ (Google Apps Script) |
| `edge/` | Edge Function แจ้งเตือนบนมือถือ |
| `test/` `demo/` | ชุดทดสอบ · ตัวสร้างเดโม |
