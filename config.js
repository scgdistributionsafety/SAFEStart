/* SafeStart · ค่าที่ต้องแก้ก่อนใช้งาน (ดู docs/SETUP.md ขั้นที่ 3) */
window.SAFESTART_CONFIG = {
  SUPABASE_URL: 'https://oyzykojhzudqwpbjirzg.supabase.co',   // Project Settings › API › Project URL
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95enlrb2poenVkcXdwYmppcnpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTExODY1NDcsImV4cCI6MjEwNjc2MjU0N30.gAJlmeVgfaCFMlE1ocjT8eWBbfkZk3_a79orqSVgmIU',                  // Project Settings › API › anon public (ห้ามใส่ service_role)
  LINE_OA_ID: '@safestart',                            // ไอดี LINE OA (แสดงในหน้า "ฉัน")
  VAPID_PUBLIC_KEY: ''                                 // จาก tools/vapid.html (ขั้นที่ 7 · ไม่ใส่ก็ได้ถ้ายังไม่เปิดแจ้งเตือนบนเครื่อง)
};
