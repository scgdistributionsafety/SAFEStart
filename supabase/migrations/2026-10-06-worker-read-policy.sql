-- 6 ต.ค. 2569 · แก้ "new row violates row-level security policy for table workers" ตอนผู้รับเหมาเพิ่มช่าง
-- รันแล้วในระบบจริง (เก็บไว้เป็นประวัติ) · รันซ้ำได้ปลอดภัย
drop policy if exists w_read on workers;
create policy w_read on workers for select using (contractor_id = my_contractor() or can_see_worker(id));
