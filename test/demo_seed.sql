-- ข้อมูลตัวอย่างสำหรับเดโมและทดสอบ (วันที่อิงวันนี้) · ห้ามรันในระบบจริง
do $$
declare d date := bkk_today(); c1 uuid; c2 uuid; ctr1 uuid := 'c1000000-0000-0000-0000-000000000001'; ctr2 uuid := 'c1000000-0000-0000-0000-000000000002'; ctr3 uuid := 'c1000000-0000-0000-0000-000000000003';
  p1 uuid := 'b1000000-0000-0000-0000-000000000001'; p2 uuid := 'b1000000-0000-0000-0000-000000000002'; p3 uuid := 'b1000000-0000-0000-0000-000000000003';
  w uuid; jt record; ci uuid; ci2 uuid;
  u text[] := array['a0000000-0000-0000-0000-0000000000'];
begin
  select id into c1 from scg_companies where short='SCGD';
  select id into c2 from scg_companies where short='SCGHE';
  update scg_companies set id=id where false;

  insert into contractors(id,name,tax_id,contact_name,contact_phone,email,safety_officer) values
    (ctr1,'บจ.ช่างดีการช่าง','0105559000011','คุณบอส','081-111-2222','boss@changdee.co.th','นายวิทยา (จป.หัวหน้างาน)'),
    (ctr2,'หจก.พรีเมียร์รูฟ','0103561000022','คุณเอ็ม','082-333-4444','m@premierroof.co.th','นางสาวพร (จป.หัวหน้างาน)'),
    (ctr3,'บจ.สวนสวยแลนด์สเคป','0105562000033','คุณใบเตย','083-555-6666','bai@suansuay.co.th',null);
  insert into contractor_links(scg_company_id,contractor_id,status,vendor_code,vendor_approved,decided_at) values
    (c2,ctr1,'approved','V-1001',true,now()),(c1,ctr1,'approved','CD-77',true,now()),(c2,ctr2,'approved','V-1002',true,now()),(c2,ctr3,'pending','V-1003',false,null);
  insert into contractor_docs(contractor_id,doc_type,file_path,expires_on) values
    (ctr1,'registration','demo/cert-reg.jpg',d+200),(ctr1,'sso','demo/cert-sso.jpg',d+20),(ctr1,'jp','demo/cert-jp.jpg',null),
    (ctr2,'registration','demo/cert-reg2.jpg',d+300),(ctr2,'sso','demo/cert-sso2.jpg',d+150);

  -- ผู้ใช้ (สร้างผ่านคำเชิญ → trigger ให้สิทธิ์)
  insert into invites(email,full_name,role,scg_company_ids,contractor_id,is_owner) values
    ('safety@demo.scg','ศรายุทธ หลงขาว','safety_admin',array[c1,c2],null,true),
    ('purchase@demo.scg','กานดา ใจดี','purchasing',array[c2],null,false),
    ('ic@demo.scg','วิภา รักษ์งาน','installation_consultant',array[c2],null,false),
    ('icqc@demo.scg','ธนา ตรวจดี','ic_qc_manager',array[c2],null,false),
    ('boss@changdee.co.th','บอส ช่างดี','contractor_admin','{}',ctr1,false),
    ('somchai@changdee.co.th','สมชาย ใจกล้า','team_lead','{}',ctr1,false),
    ('ic.d@demo.scg','ปรีชา มั่นคง','installation_consultant',array[c1],null,false),
    ('purchase.d@demo.scg','นภา สายตรง','purchasing',array[c1],null,false),
    ('exec@demo.scg','ผู้บริหาร Home Exp.','executive',array[c2],null,false),
    ('m@premierroof.co.th','เอ็ม พรีเมียร์','contractor_admin','{}',ctr2,false),
    ('lead@premierroof.co.th','ชาญ หลังคาดี','team_lead','{}',ctr2,false),
    ('msm@demo.scg','มานพ ผู้จัดการ','ms_manager',array[c2],null,false);
  insert into auth.users(id,email) values
    ('a0000000-0000-0000-0000-000000000001','safety@demo.scg'),('a0000000-0000-0000-0000-000000000002','purchase@demo.scg'),
    ('a0000000-0000-0000-0000-000000000003','ic@demo.scg'),('a0000000-0000-0000-0000-000000000004','icqc@demo.scg'),
    ('a0000000-0000-0000-0000-000000000005','boss@changdee.co.th'),('a0000000-0000-0000-0000-000000000006','somchai@changdee.co.th'),
    ('a0000000-0000-0000-0000-000000000007','ic.d@demo.scg'),('a0000000-0000-0000-0000-000000000008','purchase.d@demo.scg'),
    ('a0000000-0000-0000-0000-000000000009','exec@demo.scg'),('a0000000-0000-0000-0000-000000000010','m@premierroof.co.th'),
    ('a0000000-0000-0000-0000-000000000011','lead@premierroof.co.th'),('a0000000-0000-0000-0000-000000000012','msm@demo.scg');
  update profiles set phone='08'||lpad((right(id::text,2)::int*7919 % 100000000)::text,8,'0'), pdpa_version='2026-10-draft', pdpa_at=now();
  update profiles set pdpa_version=null, pdpa_at=null where id='a0000000-0000-0000-0000-000000000011';

  insert into projects(id,scg_company_id,group_id,name,ic_id,backup_ic_id,hospital,hospital_phone,hospital_km,lat,lng) values
    (p1,c2,(select id from install_groups where scg_company_id=c2 and name='งานติดตั้งหลังคา'),'ม.ร่มไม้ บางนา','a0000000-0000-0000-0000-000000000003',null,'รพ.จุฬารัตน์ 3','02-316-2550',4.2,13.668,100.651),
    (p2,c2,(select id from install_groups where scg_company_id=c2 and name='งานติดตั้ง Solar'),'ม.ชายทะเล บางแสน','a0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000004','รพ.สมเด็จ ณ ศรีราชา','038-320-200',9.5,13.283,100.925),
    (p3,c1,(select id from install_groups where scg_company_id=c1 and name='งานติดตั้งไม้พื้น'),'ม.สวนหลวง พระราม 9','a0000000-0000-0000-0000-000000000007',null,'รพ.พระราม 9','02-202-9999',3.1,13.753,100.630);

  -- ช่าง บจ.ช่างดีการช่าง
  insert into workers(id,contractor_id,full_name,nickname,position,nationality,phone,birth_date,id_last4,id_hash,id_verified_by,id_verified_company,id_verified_at,
      foreign_worker,work_permit_expiry,selfdec_status,selfdec_at,selfdec_until,photo_path) values
    ('d1000000-0000-0000-0000-000000000001',ctr1,'นายเอก ขยันงาน','เอก','หัวหน้างาน/Foreman','th','089-000-0001','1988-03-02','1201','h1','a0000000-0000-0000-0000-000000000002',c2,now()-interval '60 days',false,null,'ok',now()-interval '30 days',d+335,'demo/face-1.jpg'),
    ('d1000000-0000-0000-0000-000000000002',ctr1,'นายแดง ใจสู้','แดง','ช่างหลังคา','th','089-000-0002','1992-07-15','3302','h2','a0000000-0000-0000-0000-000000000002',c2,now()-interval '60 days',false,null,'ok',now()-interval '30 days',d+335,'demo/face-2.jpg'),
    ('d1000000-0000-0000-0000-000000000003',ctr1,'นายชัย กล้าหาญ','ชัย','ช่างหลังคา','th','089-000-0003','1995-01-20','4403','h3','a0000000-0000-0000-0000-000000000002',c2,now()-interval '60 days',false,null,'ok',now()-interval '30 days',d+335,'demo/face-3.jpg'),
    ('d1000000-0000-0000-0000-000000000004',ctr1,'Mr. Aung Min','โต','ผู้ช่วยช่าง','mm','089-000-0004','1997-11-05','A904','h4','a0000000-0000-0000-0000-000000000002',c2,now()-interval '40 days',true,d+180,'ok',now()-interval '30 days',d+335,'demo/face-4.jpg'),
    ('d1000000-0000-0000-0000-000000000005',ctr1,'นายบี ขยันดี','บี','ช่างทั่วไป','th','089-000-0005','1999-04-09',null,null,null,null,null,false,null,'none',null,null,null),
    ('d1000000-0000-0000-0000-000000000006',ctr1,'Mr. Sok Dara','ดารา','ผู้ช่วยช่าง','kh','089-000-0006','1994-12-12','K006','h6','a0000000-0000-0000-0000-000000000002',c2,now()-interval '20 days',true,d+90,'doctor_submitted',now()-interval '5 days',d+360,null),
    ('d1000000-0000-0000-0000-000000000007',ctr1,'นายต้น ไม้งาม','ต้น','ช่างไม้','th','089-000-0007','1990-06-30','7707','h7','a0000000-0000-0000-0000-000000000008',c1,now()-interval '90 days',false,null,'none',null,null,null),
    ('d1000000-0000-0000-0000-000000000008',ctr1,'นายหนึ่ง พื้นดี','หนึ่ง','ช่างไม้','th','089-000-0008','1993-02-14','8808','h8','a0000000-0000-0000-0000-000000000008',c1,now()-interval '90 days',false,null,'none',null,null,null);
  update workers set selfdec_doctor_path='demo/cert-doctor.jpg' where id='d1000000-0000-0000-0000-000000000006';
  -- ช่าง หจก.พรีเมียร์รูฟ
  insert into workers(id,contractor_id,full_name,nickname,position,nationality,birth_date,id_last4,id_hash,id_verified_by,id_verified_company,id_verified_at,selfdec_status,selfdec_at,selfdec_until,foreign_worker,work_permit_expiry) values
    ('d2000000-0000-0000-0000-000000000001',ctr2,'นายชาญ หลังคาดี','ชาญ','หัวหน้างาน/Foreman','th','1985-05-05','5101','h21','a0000000-0000-0000-0000-000000000002',c2,now()-interval '50 days','ok',now()-interval '100 days',d+265,false,null),
    ('d2000000-0000-0000-0000-000000000002',ctr2,'นายสุข สบายดี','สุข','ช่างไฟฟ้า','th','1991-08-08','5202','h22','a0000000-0000-0000-0000-000000000002',c2,now()-interval '50 days','ok',now()-interval '340 days',d+25,false,null),
    ('d2000000-0000-0000-0000-000000000003',ctr2,'Mr. Khamla','คำหล้า','ผู้ช่วยช่าง','la','1996-09-09','L303','h23','a0000000-0000-0000-0000-000000000002',c2,now()-interval '50 days','ok',now()-interval '100 days',d+265,true,d+200);
  update workers set id_hash=encode(extensions.hmac(id_last4||id::text,'demo','sha256'),'hex') where id_hash is not null;

  insert into worker_links(scg_company_id,worker_id,status,decided_by,decided_at) select c2,id,'approved','a0000000-0000-0000-0000-000000000002',now()-interval '30 days'
    from workers where id in ('d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000004','d1000000-0000-0000-0000-000000000006')
    or contractor_id=ctr2;
  insert into worker_links(scg_company_id,worker_id,status,requested_by) values(c2,'d1000000-0000-0000-0000-000000000005','pending','a0000000-0000-0000-0000-000000000005');
  insert into worker_links(scg_company_id,worker_id,status,decided_at) values
    (c1,'d1000000-0000-0000-0000-000000000007','approved',now()),(c1,'d1000000-0000-0000-0000-000000000008','approved',now()),(c1,'d1000000-0000-0000-0000-000000000001','approved',now());
  update workers set id_image_path='demo/idcard-5.jpg' where id='d1000000-0000-0000-0000-000000000005';

  -- cert: induction ทุกคน · wah + health คนขึ้นที่สูง · นายชัย ขาด cert ที่สูง
  insert into worker_certs(id,worker_id,cert_type,issued_on,expires_on,file_path)
  select gen_random_uuid(),w2.id,t,d-200,case when t='health' then d+165 when t='induction' then d+165 end,'demo/cert-'||t||'.jpg'
  from workers w2, unnest(array['induction','wah','health']) t
  where not (w2.id='d1000000-0000-0000-0000-000000000003' and t='wah') and not (w2.id in ('d1000000-0000-0000-0000-000000000007','d1000000-0000-0000-0000-000000000008') and t<>'induction');
  insert into cert_reviews(cert_id,scg_company_id,status,reviewed_by)
    select c.id,c2,'approved','a0000000-0000-0000-0000-000000000002' from worker_certs c join workers w2 on w2.id=c.worker_id where w2.id<>'d1000000-0000-0000-0000-000000000005';
  insert into cert_reviews(cert_id,scg_company_id,status,reviewed_by)
    select c.id,c1,'approved','a0000000-0000-0000-0000-000000000008' from worker_certs c where c.worker_id in ('d1000000-0000-0000-0000-000000000007','d1000000-0000-0000-0000-000000000008','d1000000-0000-0000-0000-000000000001');
  insert into worker_certs(worker_id,cert_type,issued_on,file_path) values('d1000000-0000-0000-0000-000000000003','wah',d-1,'demo/cert-wah-new.jpg');
  insert into selfdec_answers(worker_id,answers) select id,'{}'::jsonb from workers where selfdec_status<>'none';

  insert into teams(id,contractor_id,name,lead_id) values
    ('e0000000-0000-0000-0000-000000000001',ctr1,'ทีม A (หลังคา)','a0000000-0000-0000-0000-000000000006'),
    ('e0000000-0000-0000-0000-000000000002',ctr1,'ทีม B (ไม้พื้น)','a0000000-0000-0000-0000-000000000005'),
    ('e0000000-0000-0000-0000-000000000003',ctr2,'ทีมรูฟ 1','a0000000-0000-0000-0000-000000000011');
  insert into team_members values
    ('e0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001'),('e0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002'),
    ('e0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003'),('e0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000004'),
    ('e0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000007'),('e0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000008'),
    ('e0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000001'),
    ('e0000000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000001'),('e0000000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000002'),
    ('e0000000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000003');

  -- งาน
  insert into jobs(id,scg_company_id,project_id,contractor_id,po_no,job_type_ids,house_no,lat,lng,start_date,end_date,start_time,occupied,team_id,hazards,site_answers,setup_method,setup_worker_ids,status,stop_reason) values
   ('f0000000-0000-0000-0000-000000000001',c2,p1,ctr1,'PO-24001',array[(select id from job_types where scg_company_id=c2 and name='Roof Renovate')],'88/12',13.6672,100.6501,d,d+2,'08:00',true,
     'e0000000-0000-0000-0000-000000000001','{wah,lifting}','{"height18":true,"ladder":true,"anchor":"install","occupied":true,"lifting":true,"asbestos":false}',
     'ติดจากนั่งร้าน หรือบันไดที่ผูกยึดแล้ว',array['d1000000-0000-0000-0000-000000000001'::uuid,'d1000000-0000-0000-0000-000000000002'::uuid],'approved',null),
   ('f0000000-0000-0000-0000-000000000002',c2,p1,ctr1,'PO-24002',array[(select id from job_types where scg_company_id=c2 and name='รางน้ำใหม่')],'90/1',13.669,100.6522,d-1,d+1,'08:30',true,
     'e0000000-0000-0000-0000-000000000002','{}','{"occupied":true}',null,'{}','in_progress',null),
   ('f0000000-0000-0000-0000-000000000003',c2,p2,ctr2,'PO-24003',array[(select id from job_types where scg_company_id=c2 and name='ติดตั้งแผง + อินเวอร์เตอร์')],'12/7',13.2851,100.9262,d,d+1,'08:00',false,
     'e0000000-0000-0000-0000-000000000003','{wah,electric,lifting}','{"height18":true,"ladder":true,"anchor":"install","electric":true,"lifting":true}','คล้องโครงสร้างที่ใกล้ที่สุดก่อนขึ้น',
     array['d2000000-0000-0000-0000-000000000001'::uuid,'d2000000-0000-0000-0000-000000000003'::uuid],'in_progress',null),
   ('f0000000-0000-0000-0000-000000000004',c2,p2,ctr2,'PO-24004',array[(select id from job_types where scg_company_id=c2 and name='หลังคาใหม่/Garage')],'101/5',13.2822,100.9231,d+1,d+3,'08:00',true,
     'e0000000-0000-0000-0000-000000000003','{wah,hot,lifting}','{"height18":true,"hot":true,"scaffold":true,"anchor":"existing","occupied":true,"lifting":true}',null,'{}','permit_pending',null),
   ('f0000000-0000-0000-0000-000000000005',c2,p1,ctr1,'PO-24005',array[(select id from job_types where scg_company_id=c2 and name='ทาสี/กันซึม/ห้องน้ำ')],'77/3',13.6661,100.6489,d+1,d+2,'09:00',true,
     null,'{chemical}','{}',null,'{}','planned',null),
   ('f0000000-0000-0000-0000-000000000006',c2,p1,ctr1,'PO-24006',array[(select id from job_types where scg_company_id=c2 and name='มอเตอร์ประตูรั้ว/Door lock')],'92/8',13.6695,100.6532,d,d,'09:00',true,
     'e0000000-0000-0000-0000-000000000002','{electric}','{"electric":true,"occupied":true}',null,'{}','stopped','LSR ข้อ 2: ต่อสายไฟเข้ามอเตอร์โดยไม่ตัดไฟและไม่ล็อกตู้'),
   ('f0000000-0000-0000-0000-000000000007',c1,p3,ctr1,'PO-D1001',array[(select id from job_types where scg_company_id=c1 and name='ปูพื้นภายใน (ไม้/SPC/ลามิเนต)')],'45/2',13.7541,100.6312,d,d+1,'08:00',true,
     'e0000000-0000-0000-0000-000000000002','{}','{"occupied":true}',null,'{}','in_progress',null),
   ('f0000000-0000-0000-0000-000000000008',c1,p3,ctr1,'PO-D1002',array[(select id from job_types where scg_company_id=c1 and name='ไม้บันได/บัวพื้น')],'47/9',13.7550,100.6301,d+1,d+1,'08:00',false,
     null,'{}','{}',null,'{}','planned',null);
  insert into permits(job_id,tier,status,submitted_by,submitted_at,decided_by,decided_at,note,late) values
   ('f0000000-0000-0000-0000-000000000001','high','approved','a0000000-0000-0000-0000-000000000005',now()-interval '1 day','a0000000-0000-0000-0000-000000000003',now()-interval '20 hours',null,false),
   ('f0000000-0000-0000-0000-000000000002','low','approved','a0000000-0000-0000-0000-000000000005',now()-interval '2 days','a0000000-0000-0000-0000-000000000005',now()-interval '2 days','อนุมัติอัตโนมัติ (เสี่ยงต่ำ)',false),
   ('f0000000-0000-0000-0000-000000000003','high','approved','a0000000-0000-0000-0000-000000000010',now()-interval '1 day','a0000000-0000-0000-0000-000000000003',now()-interval '22 hours',null,false),
   ('f0000000-0000-0000-0000-000000000004','high','pending','a0000000-0000-0000-0000-000000000010',now()-interval '2 hours',null,null,null,false),
   ('f0000000-0000-0000-0000-000000000006','high','approved','a0000000-0000-0000-0000-000000000005',now()-interval '1 day','a0000000-0000-0000-0000-000000000003',now()-interval '1 day',null,false),
   ('f0000000-0000-0000-0000-000000000007','low','approved','a0000000-0000-0000-0000-000000000005',now()-interval '1 day','a0000000-0000-0000-0000-000000000005',now()-interval '1 day','อนุมัติอัตโนมัติ (เสี่ยงต่ำ)',false);

  -- check-in เมื่อวาน + ปิดงาน (PO-24002) และวันนี้
  insert into checkins(id,job_id,work_date,team_id,lead_id,worker_ids,lat,lng,distance_m,answers,photos,toolbox_topic,rules_ack,late,stage,created_at)
  values(gen_random_uuid(),'f0000000-0000-0000-0000-000000000002',d-1,'e0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000005',
    array['d1000000-0000-0000-0000-000000000001'::uuid],13.669,100.6523,12,'{}','{"team":"demo/team-1.jpg","site":"demo/site-1.jpg"}','สวมหมวกรัดสายคาง แว่นตา ถุงมือ ตลอดเวลา',true,false,'work',now()-interval '1 day') returning id into ci;
  insert into closeouts(checkin_id,job_id,answers,photos,created_by,created_at) values(ci,'f0000000-0000-0000-0000-000000000002','{}','{"after":["demo/after-1.jpg","demo/after-2.jpg"]}','a0000000-0000-0000-0000-000000000005',now()-interval '15 hours');
  insert into checkins(id,job_id,work_date,team_id,lead_id,worker_ids,lat,lng,distance_m,answers,photos,toolbox_topic,rules_ack,late,stage,created_at)
  values(gen_random_uuid(),'f0000000-0000-0000-0000-000000000002',d,'e0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000005',
    array['d1000000-0000-0000-0000-000000000001'::uuid],13.669,100.6521,8,'{"A4":{"v":"fail","photo":"demo/fail-1.jpg"}}','{"team":"demo/team-2.jpg","site":"demo/site-2.jpg"}','รู้เบอร์ 1669 และทางไปโรงพยาบาลใกล้ที่สุด',true,false,'work',now()-interval '3 hours') returning id into ci2;
  insert into findings(scg_company_id,job_id,checkin_id,source,item_code,item_text,severity,photo_path,due_at,status,created_by,created_at)
    values(c2,'f0000000-0000-0000-0000-000000000002',ci2,'checkin','A4','เครื่องมือไฟฟ้าสภาพดี มีการ์ด สายไม่ชำรุด','normal','demo/fail-1.jpg',now()+interval '45 hours','open','a0000000-0000-0000-0000-000000000005',now()-interval '3 hours');
  insert into checkins(job_id,work_date,team_id,lead_id,worker_ids,wah_worker_ids,lat,lng,distance_m,answers,photos,toolbox_topic,rules_ack,late,stage,setup_worker_ids,setup_due,created_at)
  values('f0000000-0000-0000-0000-000000000003',d,'e0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000011',
    array['d2000000-0000-0000-0000-000000000001'::uuid,'d2000000-0000-0000-0000-000000000002'::uuid,'d2000000-0000-0000-0000-000000000003'::uuid],
    array['d2000000-0000-0000-0000-000000000001'::uuid,'d2000000-0000-0000-0000-000000000003'::uuid],13.2852,100.9263,15,'{}','{"team":"demo/team-3.jpg","site":"demo/site-3.jpg"}',
    'ตรวจบันไดก่อนใช้ทุกครั้ง มุมพาด 1:4 ยื่นเลยขอบ 1 เมตร',true,false,'setup',
    array['d2000000-0000-0000-0000-000000000001'::uuid,'d2000000-0000-0000-0000-000000000003'::uuid],now()+interval '35 minutes',now()-interval '25 minutes');
  insert into checkins(id,job_id,work_date,team_id,lead_id,worker_ids,lat,lng,distance_m,answers,photos,toolbox_topic,rules_ack,late,stage,created_at)
  values(gen_random_uuid(),'f0000000-0000-0000-0000-000000000007',d,'e0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000005',
    array['d1000000-0000-0000-0000-000000000007'::uuid,'d1000000-0000-0000-0000-000000000008'::uuid],13.7542,100.6313,9,'{}','{"team":"demo/team-4.jpg","site":"demo/site-4.jpg"}',
    'สวมหมวกรัดสายคาง แว่นตา ถุงมือ ตลอดเวลา',true,false,'work',now()-interval '2 hours');
  insert into findings(scg_company_id,job_id,source,item_text,severity,photo_path,status,created_by,created_at,due_at)
    values(c2,'f0000000-0000-0000-0000-000000000006','stop','ต่อสายไฟเข้ามอเตอร์โดยไม่ตัดไฟและไม่ล็อกตู้','lsr','demo/fail-2.jpg','open','a0000000-0000-0000-0000-000000000003',now()-interval '1 hour',now());
  insert into findings(scg_company_id,job_id,checkin_id,source,item_code,item_text,severity,photo_path,due_at,status,fix_photo_path,fix_note,fixed_at,created_by,created_at)
    values(c2,'f0000000-0000-0000-0000-000000000002',ci,'checkin','A7','ชุดปฐมพยาบาล + ถังดับเพลิงพร้อมใช้ที่รถ','normal','demo/fail-3.jpg',now()+interval '20 hours','fixed','demo/fixed-1.jpg','ซื้อถังดับเพลิงใหม่ติดรถแล้ว',now()-interval '30 minutes','a0000000-0000-0000-0000-000000000005',now()-interval '1 day');
  insert into incidents(scg_company_id,job_id,contractor_id,kind,description,photos,status,reported_by,created_at)
    values(c2,'f0000000-0000-0000-0000-000000000002',ctr1,'near_miss','บันไดลื่นไถลตอนพาดขึ้นรางน้ำ ยังไม่มีใครเจ็บ ย้ายไปวางบนแผ่นยางแล้ว','{demo/site-5.jpg}','new','a0000000-0000-0000-0000-000000000005',now()-interval '50 minutes');
  insert into lsr_flags(scg_company_id,contractor_id,worker_id,job_id,rule,kind,step,penalty,ban_days,occurred_on,note,created_by)
    values(c1,ctr2,'d2000000-0000-0000-0000-000000000002',null,1,'working',1,'ห้ามทำงานกับบริษัท 7 วัน',7,d-40,'ไม่คล้องเกี่ยวขณะย้ายจุดบนหลังคา','a0000000-0000-0000-0000-000000000001');

  -- แจ้งเตือนตัวอย่าง
  perform notify('a0000000-0000-0000-0000-000000000003',c2,'permit','ใบอนุญาตเสี่ยงสูงรออนุมัติ PO-24004','ม.ชายทะเล บางแสน บ้าน 101/5 · เริ่มพรุ่งนี้','jobs','f0000000-0000-0000-0000-000000000004',false,true);
  perform notify('a0000000-0000-0000-0000-000000000005',c2,'finding','ข้อบกพร่องจาก check-in PO-24002','1 ข้อ · แก้ภายใน 48 ชม.','jobs','f0000000-0000-0000-0000-000000000002',false,true);
  perform notify('a0000000-0000-0000-0000-000000000005',c2,'stop','สั่งหยุดงาน PO-24006 (LSR ข้อ 2)','ต่อสายไฟเข้ามอเตอร์โดยไม่ตัดไฟและไม่ล็อกตู้','jobs','f0000000-0000-0000-0000-000000000006',true,true);
  perform notify('a0000000-0000-0000-0000-000000000001',c2,'incident','Near miss · PO-24002 บ้าน 90/1','บันไดลื่นไถลตอนพาดขึ้นรางน้ำ','incidents',(select id from incidents limit 1),false,true);
  perform notify('a0000000-0000-0000-0000-000000000002',c2,'worker','คำขอให้ช่างเข้าทำงาน 1 คน · บจ.ช่างดีการช่าง','ตรวจตัวบุคคลและอนุมัติในกล่องงาน','contractors',ctr1,false,true);
end $$;
