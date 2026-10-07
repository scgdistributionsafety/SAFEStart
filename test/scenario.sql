-- ทดสอบกติกาหลักทั้งหมด (รันหลัง reset.sh) · ผ่านเมื่อไม่มี ERROR และขึ้น "ALL TESTS PASSED"
\set ON_ERROR_STOP 1
\set QUIET 1
create or replace function pg_temp.u(x int) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims',json_build_object('sub','a0000000-0000-0000-0000-0000000000'||lpad(x::text,2,'0'),'role','authenticated')::text,false); end $$;
-- ต้องล้มเหลวด้วยข้อความที่มีคำนี้
create or replace function pg_temp.fails(q text, expect text) returns void language plpgsql as $$
begin
  execute q;
  raise exception 'EXPECTED FAILURE did not happen: %', q using errcode='XX999';
exception when sqlstate 'P0001' or sqlstate '42501' then
  if position(expect in sqlerrm)=0 then raise exception 'wrong error for %: % (expected %)', q, sqlerrm, expect using errcode='XX999'; end if;
  raise notice 'ok (blocked): %', sqlerrm;
end $$;
grant execute on all functions in schema pg_temp to authenticated;
\echo '1) แผนงานเสี่ยงกลาง: ผู้ดูแลบริษัทอนุมัติเอง + IC ได้แจ้งเตือน'
select pg_temp.u(5); set role authenticated;
select submit_plan('f0000000-0000-0000-0000-000000000005','e0000000-0000-0000-0000-000000000001','{"occupied":true}') ->> 'risk' as risk;
reset role;
select status, tier from permits where job_id='f0000000-0000-0000-0000-000000000005';
do $$ begin assert (select status from permits where job_id='f0000000-0000-0000-0000-000000000005')='approved'; assert exists(select 1 from notifications where to_id='a0000000-0000-0000-0000-000000000003' and title like 'แจ้งให้ทราบ: งานเสี่ยงกลาง%'); end $$;

\echo '2) แผนงานที่สูงที่ไม่มีจุดยึด = ยื่นไม่ได้'
select pg_temp.u(5); set role authenticated;
select pg_temp.fails($q$select submit_plan('f0000000-0000-0000-0000-000000000008','e0000000-0000-0000-0000-000000000002','{"height18":true,"anchor":"none"}')$q$,'ไม่มีจุดยึด');
select pg_temp.fails($q$select submit_plan('f0000000-0000-0000-0000-000000000004','e0000000-0000-0000-0000-000000000003','{}')$q$,'เฉพาะผู้ดูแลบริษัทผู้รับเหมาของงานนี้');
reset role;

\echo '3) Check-in งานหลังคา: ช่างขาด cert ที่สูงขึ้นที่สูงไม่ได้ · สุขภาพไม่ผ่าน · Buddy'
select pg_temp.u(6); set role authenticated;
create temp table pl as select jsonb_build_object(
  'lat',13.6673,'lng',100.6502,
  'worker_ids',jsonb_build_array('d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000004'),
  'wah_worker_ids',jsonb_build_array('d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000003'),
  'health',jsonb_build_array(
     jsonb_build_object('worker_id','d1000000-0000-0000-0000-000000000001','pulse',78,'sys',120,'dia',80,'alcohol',0,'photo','x/h1.jpg'),
     jsonb_build_object('worker_id','d1000000-0000-0000-0000-000000000002','pulse',88,'sys',150,'dia',95,'alcohol',0,'photo','x/h2.jpg'),
     jsonb_build_object('worker_id','d1000000-0000-0000-0000-000000000003','pulse',70,'sys',118,'dia',76,'alcohol',0,'photo','x/h3.jpg'),
     jsonb_build_object('worker_id','d1000000-0000-0000-0000-000000000004','pulse',72,'sys',110,'dia',70,'alcohol',0,'photo','x/h4.jpg')),
  'answers',(select jsonb_object_agg(code,jsonb_build_object('v','pass')) from checklist_items((select id from scg_companies where short='SCGHE')) c where sec in ('all','wah','ladder','occupied','lifting') and not setup),
  'photos',jsonb_build_object('team','x/team.jpg','site','x/site.jpg'),'rules_ack',true,'toolbox_topic','ทดสอบ','weather',jsonb_build_object('level','ok')) p;
grant all on pl to authenticated, anon;
select pg_temp.fails($q$select submit_checkin('f0000000-0000-0000-0000-000000000001',(select p from pl))$q$,'ขาด อบรมทำงานบนที่สูง');
update pl set p=jsonb_set(p,'{wah_worker_ids}','["d1000000-0000-0000-0000-000000000001","d1000000-0000-0000-0000-000000000002","d1000000-0000-0000-0000-000000000004"]');
select pg_temp.fails($q$select submit_checkin('f0000000-0000-0000-0000-000000000001',(select p from pl))$q$,'ผลตรวจสุขภาพไม่ผ่าน');
-- วัดซ้ำหลังพัก 15 นาทีผ่าน
update pl set p=jsonb_set(p,'{health}',(p->'health')||jsonb_build_array(jsonb_build_object('worker_id','d1000000-0000-0000-0000-000000000002','pulse',84,'sys',135,'dia',85,'alcohol',0,'photo','x/h2b.jpg','retest',true)));
update pl set p=jsonb_set(p,'{wah_worker_ids}','["d1000000-0000-0000-0000-000000000001"]');
select pg_temp.fails($q$select submit_checkin('f0000000-0000-0000-0000-000000000001',(select p from pl))$q$,'Buddy');
update pl set p=jsonb_set(p,'{wah_worker_ids}','["d1000000-0000-0000-0000-000000000001","d1000000-0000-0000-0000-000000000002","d1000000-0000-0000-0000-000000000004"]');
update pl set p=jsonb_set(p,'{answers,H12}','{"v":"fail","photo":"x/f.jpg"}');
select pg_temp.fails($q$select submit_checkin('f0000000-0000-0000-0000-000000000001',(select p from pl))$q$,'ต้องแก้ไขและถ่ายรูปหลังแก้');
update pl set p=jsonb_set(p,'{answers,H12}','{"v":"fail","photo":"x/f.jpg","fixed_photo":"x/fx.jpg"}');
update pl set p=jsonb_set(p,'{answers,A8}','{"v":"fail","photo":"x/a8.jpg"}');
create temp table r1 as select submit_checkin('f0000000-0000-0000-0000-000000000001',(select p from pl)) r;
grant all on r1 to anon, authenticated;
select r->>'stage' stage, r->>'findings' findings from r1;
reset role;
do $$ begin assert (select r->>'stage' from r1)='setup'; assert (select count(*) from findings where job_id='f0000000-0000-0000-0000-000000000001')=2;
  assert (select count(*) from health_checks)=5; end $$;

\echo '4) บัตรส้ม → ส่งรูปจุดยึด/ทางเดิน → บัตรเขียว'
select pg_temp.u(6); set role authenticated;
select pg_temp.fails($q$select submit_setup((select (r->>'checkin_id')::uuid from r1),'{"H3":"x/anchor.jpg"}')$q$,'ต้องส่งรูป');
select submit_setup((select (r->>'checkin_id')::uuid from r1),'{"H3":"x/anchor.jpg","H6":"x/walk.jpg"}')->>'stage' as stage;
reset role;

\echo '5) สแกนบัตรผ่าน: คนนอกเห็นแค่ผ่าน/ไม่ผ่าน · SCG เห็นรายละเอียด'
select set_config('request.jwt.claims','{}',false); set role anon;
select verify_pass((select r->>'token' from r1)) ? 'workers' as anon_sees_workers, (verify_pass((select r->>'token' from r1))->>'valid') as valid;
reset role;
select pg_temp.u(3); set role authenticated;
select jsonb_array_length(verify_pass((select r->>'token' from r1))->'workers') as ic_sees_workers;
reset role;
select pg_temp.u(7); set role authenticated;   -- IC ของอีกบริษัท
select verify_pass((select r->>'token' from r1)) ? 'workers' as other_company_sees_workers;
reset role;

\echo '6) สิทธิ์การมองเห็น (RLS)'
select pg_temp.u(10); set role authenticated;  select count(*) as premier_sees_changdee_jobs from jobs where contractor_id='c1000000-0000-0000-0000-000000000001'; reset role;
select pg_temp.u(7); set role authenticated;   select count(*) as scgd_ic_sees_jobs, count(*) filter (where scg_company_id<>(select id from scg_companies where short='SCGD')) as other_co from jobs; reset role;
select pg_temp.u(3); set role authenticated;   select count(*) as ic_health_rows from health_checks; select count(*) as ic_selfdec from selfdec_answers; reset role;
select pg_temp.u(6); set role authenticated;   select count(*) as lead_health_rows from health_checks; reset role;
select pg_temp.u(5); set role authenticated;   select count(*) as admin_health_rows from health_checks; select count(*) as admin_selfdec from selfdec_answers; reset role;
select pg_temp.u(1); set role authenticated;   select count(*) as safety_health_rows from health_checks; select count(*) as safety_selfdec from selfdec_answers; reset role;
select pg_temp.u(9); set role authenticated;   select count(*) as exec_jobs from jobs; reset role;
do $$ begin
  perform pg_temp.u(10); set local role authenticated; assert (select count(*) from jobs where contractor_id='c1000000-0000-0000-0000-000000000001')=0; reset role;
  perform pg_temp.u(3); set local role authenticated; assert (select count(*) from health_checks)=0; assert (select count(*) from selfdec_answers)=0; reset role;
  perform pg_temp.u(1); set local role authenticated; assert (select count(*) from health_checks)>0; assert (select count(*) from selfdec_answers)=0; reset role;
end $$;

\echo '7) ผู้รับเหมาแก้สถานะช่างเองไม่ได้'
select pg_temp.u(5); set role authenticated;
update workers set id_verified_at=now(), selfdec_status='ok', id_last4='9999' where id='d1000000-0000-0000-0000-000000000005';
select pg_temp.fails($q$insert into worker_links(scg_company_id,worker_id,status) values((select id from scg_companies where short='SCGHE'),'d1000000-0000-0000-0000-000000000007','approved')$q$,'permission denied');
reset role;
do $$ begin assert (select id_verified_at is null and selfdec_status='none' from workers where id='d1000000-0000-0000-0000-000000000005'); end $$;

\echo '8) Purchasing ตรวจตัวบุคคล (hash) แล้วอนุมัติ · เลขบัตรผิดถูกปฏิเสธ'
select pg_temp.u(2); set role authenticated;
select pg_temp.fails($q$select verify_worker_id('d1000000-0000-0000-0000-000000000005','1101700123450',(select id from scg_companies where short='SCGHE'))$q$,'เลขบัตรประชาชนไม่ถูกต้อง');
select pg_temp.fails($q$select decide_worker((select id from scg_companies where short='SCGHE'),'d1000000-0000-0000-0000-000000000005',true,null)$q$,'ต้องตรวจตัวบุคคลก่อน');
select verify_worker_id('d1000000-0000-0000-0000-000000000005','1-1017-00123-45-6',(select id from scg_companies where short='SCGHE')) as dup;
select decide_worker((select id from scg_companies where short='SCGHE'),'d1000000-0000-0000-0000-000000000005',true,null);
reset role;
select id_last4, length(id_hash) as hash_len, id_image_path from workers where id='d1000000-0000-0000-0000-000000000005';

\echo '9) Self-declaration: ตอบ "เคย" → ต้องมีใบแพทย์ → Safety รับรอง'
select pg_temp.u(5); set role authenticated;
select submit_selfdec('d1000000-0000-0000-0000-000000000005',(select jsonb_object_agg(i::text,case when i=3 then 'yes' else 'no' end) from generate_series(1,22) i)) as st;
select submit_selfdec_doctor('d1000000-0000-0000-0000-000000000005','x/doctor.jpg');
reset role;
select pg_temp.u(1); set role authenticated; select review_selfdec_doctor('d1000000-0000-0000-0000-000000000005',true,null); reset role;
select selfdec_status from workers where id='d1000000-0000-0000-0000-000000000005';

\echo '10) IC อนุมัติใบอนุญาตเสี่ยงสูง · IC อีกบริษัทอนุมัติไม่ได้'
select pg_temp.u(7); set role authenticated;
select pg_temp.fails($q$select decide_permit((select id from permits where job_id='f0000000-0000-0000-0000-000000000004'),true,null)$q$,'ไม่พบ');
reset role;
select pg_temp.u(3); set role authenticated;
select pg_temp.fails($q$select decide_permit((select id from permits where job_id='f0000000-0000-0000-0000-000000000004'),false,'')$q$,'ใส่เหตุผล');
select decide_permit((select id from permits where job_id='f0000000-0000-0000-0000-000000000004'),true,'ตรวจนั่งร้านก่อนขึ้น');
reset role;

\echo '11) บันทึกโทษ LSR: ห้ามทำงานเฉพาะบริษัทเจ้าของเคส · บริษัทอื่นเห็น Flag'
select pg_temp.u(1); set role authenticated;
select record_lsr((select id from scg_companies where short='SCGHE'),'d1000000-0000-0000-0000-000000000002',null,'f0000000-0000-0000-0000-000000000001',1,null,'ไม่คล้องเกี่ยว') as lsr;
select worker_blockers('d1000000-0000-0000-0000-000000000002',(select id from scg_companies where short='SCGHE'),'{}',bkk_today(),false) as blocked_scghe;
select record_lsr((select id from scg_companies where short='SCGHE'),'d1000000-0000-0000-0000-000000000002',null,null,1,null,'ซ้ำ')->>'penalty' as second;
reset role;
select pg_temp.u(8); set role authenticated;
select jsonb_array_length(worker_flags('d1000000-0000-0000-0000-000000000002')) as scgd_sees_flags;
reset role;

\echo '12) สั่งหยุดงาน (LSR) → check-in วันนี้ถูกยกเลิก → ปลดล็อก'
select pg_temp.u(3); set role authenticated;
select stop_job('f0000000-0000-0000-0000-000000000001','ไม่คล้องเกี่ยวบนหลังคา',1,'scg/stop.jpg');
reset role;
do $$ begin assert (select voided from checkins where id=(select (r->>'checkin_id')::uuid from r1)); end $$;
select set_config('request.jwt.claims','{}',false); set role anon; select verify_pass((select r->>'token' from r1))->>'valid' as pass_after_stop; reset role;
select pg_temp.u(6); set role authenticated;
select pg_temp.fails($q$select submit_checkin('f0000000-0000-0000-0000-000000000001',(select p from pl))$q$,'ถูกสั่งหยุด');
reset role;
select pg_temp.u(3); set role authenticated; select resume_job('f0000000-0000-0000-0000-000000000001','แก้ไขแล้ว'); reset role;

\echo '13) แจ้งเหตุ / SOS'
select pg_temp.u(6); set role authenticated;
select sos('f0000000-0000-0000-0000-000000000001',13.667,100.65)->>'hospital' as hospital;
select report_incident(null,'f0000000-0000-0000-0000-000000000001','unsafe_condition','สายพ่วงเปียกน้ำ',null,null,null) is not null as reported;
reset role;
do $$ begin assert (select count(*) from notifications where kind='incident' and urgent and to_id='a0000000-0000-0000-0000-000000000003')>=1; end $$;

\echo '14) นำเข้า PO: โครงการใหม่สร้างอัตโนมัติ + แถวผิดถูกรายงาน'
select pg_temp.u(2); set role authenticated;
select import_jobs((select id from scg_companies where short='SCGHE'),'[
  {"po_no":"PO-30001","project":"ม.ใหม่ ทดสอบ","contractor":"V-1001","job_types":"รางน้ำใหม่","start_date":"2026-12-01","house_no":"1/1"},
  {"po_no":"PO-30002","project":"ม.ใหม่ ทดสอบ","contractor":"ไม่มีบริษัทนี้","job_types":"ไม่มีงานนี้","start_date":"01/12/2026"}]') as res;
reset role;
select name, auto_created from projects where name='ม.ใหม่ ทดสอบ';

\echo '15) เชิญผู้ใช้: ใครเชิญใครได้'
select pg_temp.u(5); set role authenticated;
select invite_user('newlead@changdee.co.th','ช่างใหม่','team_lead','{}','c1000000-0000-0000-0000-000000000001');
select pg_temp.fails($q$select invite_user('x@x.com','x','safety_admin',array[(select id from scg_companies where short='SCGHE')],null)$q$,'ไม่มีสิทธิ์');
reset role;
select pg_temp.u(1); set role authenticated;
select invite_user('newic@demo.scg','IC ใหม่','installation_consultant',array[(select id from scg_companies where short='SCGHE')],null);
reset role;
insert into auth.users(id,email) values('a0000000-0000-0000-0000-000000000099','NewIC@demo.scg');
select role, cardinality(scg_company_ids) cos from profiles where id='a0000000-0000-0000-0000-000000000099';

\echo '16) ส่งต่อเมื่อไม่รับทราบ + ส่งซ้ำเรื่องด่วน + บัตรส้มเกินเวลา'
update notifications set escalate_at=now()-interval '1 minute' where to_id='a0000000-0000-0000-0000-000000000006' and need_ack and ack_at is null;
update checkins set setup_due=now()-interval '1 minute' where stage='setup';
select run_escalations();
select count(*) as escalated_to_admin from notifications where to_id='a0000000-0000-0000-0000-000000000005' and title like 'ส่งต่อ%';
select run_daily('morning'), run_daily('missing_checkin'), run_daily('evening');
select today_summary((select id from scg_companies where short='SCGHE'));

\echo '17) ปิดงานประจำวัน (PO-24002) และ Finding: แก้ → ตรวจรับ'
select pg_temp.u(5); set role authenticated;
select submit_closeout((select id from checkins where job_id='f0000000-0000-0000-0000-000000000002' and work_date=bkk_today()),
  jsonb_build_object('answers',(select jsonb_object_agg(x->>'code','pass') from jsonb_array_elements(setting(null,'closeout')) x),'photos','{"after":["x/a1.jpg","x/a2.jpg"]}'::jsonb,'incident',false));
select fix_finding((select id from findings where item_code='A4' and job_id='f0000000-0000-0000-0000-000000000002'),'x/fix.jpg','เปลี่ยนสายใหม่');
reset role;
select pg_temp.u(3); set role authenticated;
select verify_finding((select id from findings where item_code='A4' and job_id='f0000000-0000-0000-0000-000000000002'),true,null);
reset role;

\echo '18) Purchasing ค้นผู้รับเหมาด้วยเลขภาษี + เพิ่มเข้าทะเบียนบริษัทตัวเอง'
select pg_temp.u(8); set role authenticated;
select find_contractor('0103561000022')->>'name' as found, jsonb_array_length(find_contractor('0103561000022')->'flags') as flags;
select register_contractor((select id from scg_companies where short='SCGD'),'x','0103561000022',null,null,null,'PR-9',true) is not null as linked;
select count(*) as now_sees_premier_workers from workers where contractor_id='c1000000-0000-0000-0000-000000000002';
reset role;

\echo 'ALL TESTS PASSED'
