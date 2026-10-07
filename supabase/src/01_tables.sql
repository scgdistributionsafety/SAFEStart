-- =====================================================================
-- SafeStart v2 · ระบบความปลอดภัยผู้รับเหมา (หลายบริษัท SCG)
-- ตาราง สิทธิ์ (RLS) และกติกาทั้งหมด · รันใน Supabase › SQL Editor ทีเดียวทั้งไฟล์
-- ลำดับ: schema.sql → seed.sql
-- โครงสร้าง: บริษัท SCG → กลุ่มงานติดตั้ง → โครงการ → งาน (PO)
--            ผู้รับเหมาและช่างเป็นทะเบียนกลาง แต่ละบริษัท SCG อนุมัติส่วนของตัวเอง
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- 1) องค์กร SCG
-- ---------------------------------------------------------------------
create table scg_companies(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short text,
  color text not null default '#0B6B4A',
  active boolean not null default true,
  created_at timestamptz not null default now());

create table install_groups(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies on delete cascade,
  name text not null,
  sort int not null default 0,
  active boolean not null default true,
  unique(scg_company_id,name));

create table profiles(
  id uuid primary key references auth.users on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role text not null default 'pending' check (role in ('pending','team_lead','contractor_admin',
    'installation_consultant','purchasing','ic_qc_manager','ms_manager','ms_director','safety_admin','executive')),
  scg_company_ids uuid[] not null default '{}',
  contractor_id uuid,
  is_owner boolean not null default false,
  active boolean not null default true,
  line_user_id text,
  line_link_code text,
  pdpa_version text,
  pdpa_at timestamptz,
  created_at timestamptz not null default now());

create table invites(
  email text primary key,
  full_name text,
  role text not null,
  scg_company_ids uuid[] not null default '{}',
  contractor_id uuid,
  is_owner boolean not null default false,
  invited_by uuid,
  created_at timestamptz not null default now());

create table projects(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies on delete cascade,
  group_id uuid references install_groups,
  name text not null,
  ic_id uuid references profiles,
  backup_ic_id uuid references profiles,
  hospital text, hospital_phone text, hospital_km numeric,
  lat double precision, lng double precision,
  auto_created boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(scg_company_id,name));

create table job_types(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies on delete cascade,
  group_id uuid references install_groups,
  name text not null,
  hazards text[] not null default '{}',
  extra text[] not null default '{}',          -- เช่น asbestos (ถามเพิ่มตอนยื่นแผน)
  active boolean not null default true,
  unique(scg_company_id,name));

-- ค่าตั้งค่า: scg_company_id ว่าง = ค่ากลาง · มีค่า = ทับเฉพาะบริษัทนั้น
create table settings(
  id bigint generated always as identity primary key,
  scg_company_id uuid references scg_companies on delete cascade,
  key text not null,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  unique nulls not distinct (scg_company_id,key));

create table app_secrets(key text primary key, value text not null);   -- อ่านได้เฉพาะฟังก์ชันในฐานข้อมูล

-- ---------------------------------------------------------------------
-- 2) ผู้รับเหมา (ทะเบียนกลาง) + การเชื่อมกับแต่ละบริษัท SCG
-- ---------------------------------------------------------------------
create table contractors(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tax_id text unique check (tax_id ~ '^[0-9]{13}$'),
  address text, contact_name text, contact_phone text, email text,
  safety_officer text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
alter table profiles add constraint profiles_contractor_fk foreign key (contractor_id) references contractors;
alter table invites add constraint invites_contractor_fk foreign key (contractor_id) references contractors;

create table contractor_links(
  scg_company_id uuid not null references scg_companies on delete cascade,
  contractor_id uuid not null references contractors on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','suspended')),
  vendor_code text,
  vendor_approved boolean not null default false,
  note text,
  decided_by uuid, decided_at timestamptz,
  created_at timestamptz not null default now(),
  primary key(scg_company_id,contractor_id));

create table contractor_docs(
  id uuid primary key default gen_random_uuid(),
  contractor_id uuid not null references contractors on delete cascade,
  doc_type text not null check (doc_type in ('registration','sso','jp','other')),
  file_path text not null,
  expires_on date,
  note text,
  uploaded_by uuid,
  created_at timestamptz not null default now());

create table workers(
  id uuid primary key default gen_random_uuid(),
  contractor_id uuid not null references contractors on delete cascade,
  full_name text not null,
  nickname text,
  position text,
  nationality text not null default 'th' check (nationality in ('th','mm','kh','la','other')),
  phone text,
  birth_date date,
  photo_path text,
  id_last4 text,
  id_hash text,
  id_image_path text,                     -- รูปบัตรชั่วคราว ลบทันทีหลังตรวจ
  id_verified_by uuid, id_verified_company uuid, id_verified_at timestamptz,
  foreign_worker boolean not null default false,
  work_permit_expiry date,
  insurance_no text, insurance_expiry date,
  selfdec_status text not null default 'none' check (selfdec_status in ('none','ok','need_doctor','doctor_submitted','doctor_ok')),
  selfdec_at timestamptz,
  selfdec_until date,
  selfdec_doctor_path text,
  selfdec_reviewed_by uuid,
  active boolean not null default true,
  requested_by uuid,
  created_at timestamptz not null default now());
create index on workers(contractor_id);
create index on workers(id_hash);

-- คำตอบ Self-declaration (ข้อมูลสุขภาพ) · เห็นเฉพาะผู้ดูแลบริษัทผู้รับเหมา
create table selfdec_answers(
  worker_id uuid primary key references workers on delete cascade,
  answers jsonb not null,
  signed_at timestamptz not null default now(),
  updated_by uuid);

create table worker_links(
  scg_company_id uuid not null references scg_companies on delete cascade,
  worker_id uuid not null references workers on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  banned_until date,
  banned_forever boolean not null default false,
  requested_by uuid, decided_by uuid, decided_at timestamptz, note text,
  created_at timestamptz not null default now(),
  primary key(scg_company_id,worker_id));

create table worker_certs(
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references workers on delete cascade,
  cert_type text not null,
  issued_on date, expires_on date,
  file_path text not null,
  created_by uuid,
  created_at timestamptz not null default now());

-- แต่ละบริษัท SCG รับรองไฟล์ cert เอง
create table cert_reviews(
  cert_id uuid not null references worker_certs on delete cascade,
  scg_company_id uuid not null references scg_companies on delete cascade,
  status text not null check (status in ('approved','rejected')),
  note text, reviewed_by uuid, reviewed_at timestamptz not null default now(),
  primary key(cert_id,scg_company_id));

-- Flag กฎพิทักษ์ชีวิต (แชร์ข้ามบริษัทแบบแจ้งให้ทราบ)
create table lsr_flags(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies,
  contractor_id uuid not null references contractors,
  worker_id uuid references workers,
  job_id uuid,
  rule int not null check (rule between 1 and 9),
  kind text not null default 'working' check (kind in ('working','driving')),
  step int not null default 1,
  penalty text not null,
  ban_days int,
  ban_forever boolean not null default false,
  occurred_on date not null,
  note text,
  created_by uuid,
  created_at timestamptz not null default now());

create table flag_acks(
  flag_id uuid not null references lsr_flags on delete cascade,
  scg_company_id uuid not null references scg_companies on delete cascade,
  ack_by uuid, ack_at timestamptz not null default now(), context text,
  primary key(flag_id,scg_company_id,context));

create table teams(
  id uuid primary key default gen_random_uuid(),
  contractor_id uuid not null references contractors on delete cascade,
  name text not null,
  lead_id uuid references profiles,
  created_at timestamptz not null default now());
create table team_members(
  team_id uuid not null references teams on delete cascade,
  worker_id uuid not null references workers on delete cascade,
  primary key(team_id,worker_id));

-- ---------------------------------------------------------------------
-- 3) งาน ใบอนุญาต check-in ปิดงาน
-- ---------------------------------------------------------------------
create table jobs(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies,
  project_id uuid not null references projects,
  contractor_id uuid not null references contractors,
  po_no text not null,
  job_type_ids uuid[] not null default '{}',
  house_no text, address text,
  lat double precision, lng double precision,
  start_date date not null, end_date date not null,
  start_time time not null default '08:00',
  occupied boolean not null default false,
  team_id uuid references teams,
  hazards text[] not null default '{}',
  risk text not null default 'low' check (risk in ('low','med','high')),
  site_answers jsonb not null default '{}',
  setup_method text,
  setup_worker_ids uuid[] not null default '{}',
  status text not null default 'planned' check (status in ('planned','permit_pending','approved','in_progress','stopped','done','cancelled')),
  stop_reason text,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique(scg_company_id,po_no),
  check (end_date>=start_date));
create index on jobs(contractor_id,start_date);
create index on jobs(scg_company_id,start_date);

create table permits(
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs on delete cascade,
  tier text not null check (tier in ('low','med','high')),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  late boolean not null default false,
  submitted_by uuid, submitted_at timestamptz not null default now(),
  decided_by uuid, decided_at timestamptz,
  note text);

create table checkins(
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs on delete cascade,
  work_date date not null,
  team_id uuid,
  lead_id uuid,
  worker_ids uuid[] not null,
  wah_worker_ids uuid[] not null default '{}',
  lat double precision, lng double precision, distance_m int,
  out_of_radius_reason text,
  answers jsonb not null default '{}',
  photos jsonb not null default '{}',
  toolbox_topic text,
  rules_ack boolean not null default false,
  weather jsonb,
  weather_choice text,
  late boolean not null default false,
  stage text not null default 'work' check (stage in ('setup','work')),
  setup_worker_ids uuid[] not null default '{}',
  setup_due timestamptz,
  setup_photos jsonb not null default '{}',
  setup_done_at timestamptz,
  setup_overdue_sent boolean not null default false,
  pass_token text not null unique default encode(extensions.gen_random_bytes(12),'hex'),
  voided boolean not null default false,
  void_reason text,
  created_at timestamptz not null default now());
create unique index checkins_one_per_day on checkins(job_id,work_date) where not voided;

-- ผลตรวจสุขภาพประจำวัน (คนที่ขึ้นที่สูง) · ค่าที่วัดเห็นเฉพาะผู้ดูแลบริษัทผู้รับเหมาและ Safety
create table health_checks(
  id uuid primary key default gen_random_uuid(),
  checkin_id uuid not null references checkins on delete cascade,
  worker_id uuid not null references workers,
  work_date date not null,
  pulse int, sys int, dia int, alcohol numeric,
  photo_path text,
  retest boolean not null default false,
  pass boolean not null,
  created_at timestamptz not null default now());

create table closeouts(
  id uuid primary key default gen_random_uuid(),
  checkin_id uuid not null unique references checkins on delete cascade,
  job_id uuid not null references jobs on delete cascade,
  answers jsonb not null default '{}',
  photos jsonb not null default '{}',
  damage boolean not null default false,
  damage_note text,
  incident boolean not null default false,
  final boolean not null default false,
  created_by uuid,
  created_at timestamptz not null default now());

create table findings(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies,
  job_id uuid not null references jobs on delete cascade,
  checkin_id uuid references checkins on delete set null,
  source text not null check (source in ('checkin','linewalk','stop')),
  item_code text, item_text text not null,
  severity text not null default 'normal' check (severity in ('lsr','critical','high','normal')),
  photo_path text,
  due_at timestamptz,
  status text not null default 'open' check (status in ('open','fixed','verified')),
  fix_photo_path text, fix_note text, fixed_at timestamptz,
  verified_by uuid, verified_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now());

-- แจ้งเหตุ / SOS / Near miss (รอบนี้: แจ้ง + คัดกรอง · การสอบสวนเต็มรูปแบบอยู่รอบถัดไป)
create table incidents(
  id uuid primary key default gen_random_uuid(),
  scg_company_id uuid not null references scg_companies,
  job_id uuid references jobs on delete set null,
  contractor_id uuid references contractors,
  kind text not null check (kind in ('sos','injury','property','near_miss','unsafe_condition','unsafe_act')),
  level text,
  description text,
  photos text[] not null default '{}',
  lat double precision, lng double precision,
  status text not null default 'new' check (status in ('new','acknowledged','closed')),
  handled_by uuid, handled_at timestamptz, handle_note text,
  reported_by uuid,
  created_at timestamptz not null default now());

create table notifications(
  id uuid primary key default gen_random_uuid(),
  to_id uuid not null references profiles on delete cascade,
  scg_company_id uuid,
  kind text not null,
  title text not null,
  body text,
  ref_table text, ref_id uuid,
  urgent boolean not null default false,
  need_ack boolean not null default true,
  ack_at timestamptz,
  escalate_at timestamptz,
  escalated boolean not null default false,
  repeat_at timestamptz,
  sent_line_at timestamptz,
  sent_email_at timestamptz,
  sent_push_at timestamptz,
  created_at timestamptz not null default now());
create index on notifications(to_id,created_at desc);
create index on notifications(escalate_at) where ack_at is null and not escalated;

create table push_subs(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  endpoint text not null unique,
  keys jsonb not null,
  created_at timestamptz not null default now());

create table audit_log(
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor uuid,
  scg_company_id uuid,
  action text not null,
  ref_table text, ref_id uuid,
  detail jsonb);

-- =====================================================================
-- 4) ตัวช่วย
-- =====================================================================
create or replace function bkk_now() returns timestamp language sql stable as $$ select (now() at time zone 'Asia/Bangkok') $$;
create or replace function bkk_today() returns date language sql stable as $$ select (now() at time zone 'Asia/Bangkok')::date $$;

create or replace function my_profile() returns profiles language sql stable security definer set search_path=public as
$$ select * from profiles where id=auth.uid() and active $$;
create or replace function my_role() returns text language sql stable security definer set search_path=public as
$$ select coalesce((select role from profiles where id=auth.uid() and active),'none') $$;
create or replace function my_contractor() returns uuid language sql stable security definer set search_path=public as
$$ select contractor_id from profiles where id=auth.uid() and active and role in ('team_lead','contractor_admin') $$;
create or replace function is_scg() returns boolean language sql stable as
$$ select my_role() in ('installation_consultant','purchasing','ic_qc_manager','ms_manager','ms_director','safety_admin','executive') $$;
create or replace function is_contractor() returns boolean language sql stable as
$$ select my_role() in ('team_lead','contractor_admin') $$;
create or replace function is_owner() returns boolean language sql stable security definer set search_path=public as
$$ select coalesce((select is_owner from profiles where id=auth.uid() and active),false) $$;
-- บริษัท SCG ที่ฉันเห็น (SCG = ที่สังกัด · ผู้รับเหมา = ที่เชื่อมอยู่และยังไม่ถูกปฏิเสธ)
create or replace function my_cos() returns uuid[] language sql stable security definer set search_path=public as $$
  select case when is_scg() then (select scg_company_ids from profiles where id=auth.uid())
    when is_contractor() then coalesce((select array_agg(scg_company_id) from contractor_links where contractor_id=my_contractor()),'{}')
    else '{}'::uuid[] end $$;
create or replace function has_co(co uuid) returns boolean language sql stable as $$ select is_scg() and co = any(my_cos()) $$;
create or replace function role_in(co uuid, roles text[]) returns boolean language sql stable as $$ select has_co(co) and my_role() = any(roles) $$;
create or replace function is_safety(co uuid) returns boolean language sql stable as $$ select role_in(co,array['safety_admin']) $$;

create or replace function setting(co uuid, k text) returns jsonb language sql stable security definer set search_path=public as $$
  select coalesce((select value from settings where scg_company_id=co and key=k),(select value from settings where scg_company_id is null and key=k)) $$;
create or replace function sett_int(co uuid, k text, f text, d int) returns int language sql stable as $$ select coalesce((setting(co,k)->>f)::int,d) $$;

create or replace function can_see_job(jid uuid) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from jobs j where j.id=jid and ((is_scg() and j.scg_company_id=any(my_cos())) or (is_contractor() and j.contractor_id=my_contractor()))) $$;
create or replace function can_see_worker(wid uuid) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from workers w where w.id=wid and (w.contractor_id=my_contractor()
    or (is_scg() and exists(select 1 from worker_links l where l.worker_id=w.id and l.scg_company_id=any(my_cos())))
    or (is_scg() and exists(select 1 from contractor_links c where c.contractor_id=w.contractor_id and c.scg_company_id=any(my_cos()))))) $$;
create or replace function can_see_contractor(cid uuid) returns boolean language sql stable security definer set search_path=public as $$
  select cid=my_contractor() or (is_scg() and exists(select 1 from contractor_links c where c.contractor_id=cid and c.scg_company_id=any(my_cos()))) $$;

create or replace function audit(co uuid, act text, tbl text, rid uuid, det jsonb default null) returns void language sql security definer set search_path=public as
$$ insert into audit_log(actor,scg_company_id,action,ref_table,ref_id,detail) values(auth.uid(),co,act,tbl,rid,det) $$;

-- แจ้งเตือน 1 คน
create or replace function notify(p_to uuid, p_co uuid, p_kind text, p_title text, p_body text, p_tbl text, p_id uuid,
  p_urgent boolean default false, p_ack boolean default true) returns void language plpgsql security definer set search_path=public as $$
declare mins int;
begin
  if p_to is null then return; end if;
  if not exists(select 1 from profiles where id=p_to and active) then return; end if;
  mins := case when p_urgent then sett_int(p_co,'sla','ack_urgent_min',30) else sett_int(p_co,'sla','ack_normal_min',240) end;
  insert into notifications(to_id,scg_company_id,kind,title,body,ref_table,ref_id,urgent,need_ack,escalate_at,repeat_at)
  values(p_to,p_co,p_kind,p_title,p_body,p_tbl,p_id,p_urgent,p_ack,
    case when p_ack then now()+make_interval(mins=>mins) end,
    case when p_urgent and p_ack then now()+interval '5 minutes' end);
end $$;
create or replace function notify_many(p_to uuid[], p_co uuid, p_kind text, p_title text, p_body text, p_tbl text, p_id uuid,
  p_urgent boolean default false, p_ack boolean default true) returns void language plpgsql security definer set search_path=public as $$
declare u uuid;
begin
  for u in select distinct x from unnest(p_to) x where x is not null and x<>coalesce(auth.uid(),'00000000-0000-0000-0000-000000000000') loop
    perform notify(u,p_co,p_kind,p_title,p_body,p_tbl,p_id,p_urgent,p_ack);
  end loop;
end $$;

create or replace function co_users(co uuid, roles text[]) returns uuid[] language sql stable security definer set search_path=public as $$
  select coalesce(array_agg(id),'{}') from profiles where active and role=any(roles) and co=any(scg_company_ids) $$;
create or replace function contractor_admins(cid uuid) returns uuid[] language sql stable security definer set search_path=public as $$
  select coalesce(array_agg(id),'{}') from profiles where active and role='contractor_admin' and contractor_id=cid $$;
-- ผู้รับผิดชอบโครงการ: IC → IC สำรอง → IC & QC Manager → Safety
create or replace function project_ics(pid uuid) returns uuid[] language sql stable security definer set search_path=public as $$
  select case when p.ic_id is not null or p.backup_ic_id is not null then array_remove(array[p.ic_id,p.backup_ic_id],null)
    else co_users(p.scg_company_id,array['ic_qc_manager','safety_admin']) end from projects p where p.id=pid $$;
create or replace function job_lead(jid uuid) returns uuid language sql stable security definer set search_path=public as $$
  select t.lead_id from jobs j join teams t on t.id=j.team_id where j.id=jid $$;

create or replace function distance_m(a double precision,b double precision,c double precision,d double precision) returns int language sql immutable as $$
  select round(2*6371000*asin(sqrt(power(sin(radians(c-a)/2),2)+cos(radians(a))*cos(radians(c))*power(sin(radians(d-b)/2),2))))::int $$;

create or replace function hazard_risk(h text[]) returns text language sql immutable as $$
  select case when h && array['wah','electric','hot','confined'] then 'high' when h && array['lifting','excavation','chemical'] then 'med' else 'low' end $$;

-- อายุ (ปี) ณ วันที่
create or replace function age_on(b date, d date) returns int language sql immutable as $$ select extract(year from age(d,b))::int $$;

-- =====================================================================
-- 5) Trigger
-- =====================================================================
-- ผู้ใช้ใหม่: สิทธิ์มาจากคำเชิญเท่านั้น
create or replace function on_auth_user() returns trigger language plpgsql security definer set search_path=public as $$
declare i invites;
begin
  select * into i from invites where lower(email)=lower(new.email);
  insert into profiles(id,email,full_name,role,scg_company_ids,contractor_id,is_owner)
  values(new.id,lower(new.email),i.full_name,coalesce(i.role,'pending'),coalesce(i.scg_company_ids,'{}'),i.contractor_id,coalesce(i.is_owner,false))
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user after insert on auth.users for each row execute function on_auth_user();

-- กันผู้รับเหมาแก้สถานะ/ผลตรวจของช่างเอง
create or replace function guard_worker() returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated','anon') then
    if tg_op='INSERT' then
      new.id_last4:=null; new.id_hash:=null; new.id_verified_by:=null; new.id_verified_company:=null; new.id_verified_at:=null;
      new.selfdec_status:='none'; new.selfdec_at:=null; new.selfdec_until:=null; new.selfdec_reviewed_by:=null; new.selfdec_doctor_path:=null;
      new.requested_by:=auth.uid();
    else
      new.id_last4:=old.id_last4; new.id_hash:=old.id_hash; new.id_verified_by:=old.id_verified_by; new.id_verified_company:=old.id_verified_company;
      new.id_verified_at:=old.id_verified_at; new.contractor_id:=old.contractor_id;
      new.selfdec_status:=old.selfdec_status; new.selfdec_at:=old.selfdec_at; new.selfdec_until:=old.selfdec_until;
      new.selfdec_reviewed_by:=old.selfdec_reviewed_by; new.selfdec_doctor_path:=old.selfdec_doctor_path;
      if old.id_verified_at is not null then new.id_image_path:=null; end if;
    end if;
  end if;
  return new;
end $$;
create trigger guard_worker before insert or update on workers for each row execute function guard_worker();

-- ผู้รับเหมาแก้ข้อมูลพื้นฐาน → ทุกบริษัทที่เชื่อมอยู่ได้แจ้งเตือน (ไม่ต้องรับทราบ)
create or replace function on_contractor_update() returns trigger language plpgsql security definer set search_path=public as $$
declare l record;
begin
  new.updated_at:=now();
  if current_user='authenticated' and (new.name,new.tax_id,new.contact_name,new.safety_officer) is distinct from (old.name,old.tax_id,old.contact_name,old.safety_officer) then
    for l in select scg_company_id from contractor_links where contractor_id=new.id loop
      perform notify_many(co_users(l.scg_company_id,array['purchasing']),l.scg_company_id,'contractor','ผู้รับเหมาแก้ข้อมูลบริษัท: '||new.name,null,'contractors',new.id,false,false);
    end loop;
  end if;
  return new;
end $$;
create trigger on_contractor_update before update on contractors for each row execute function on_contractor_update();

create or replace function job_risk() returns trigger language plpgsql as $$
begin new.risk:=hazard_risk(new.hazards); return new; end $$;
create trigger job_risk before insert or update of hazards on jobs for each row execute function job_risk();

-- =====================================================================
-- 6) RLS
-- =====================================================================
alter table scg_companies enable row level security;
alter table install_groups enable row level security;
alter table profiles enable row level security;
alter table invites enable row level security;
alter table projects enable row level security;
alter table job_types enable row level security;
alter table settings enable row level security;
alter table app_secrets enable row level security;
alter table contractors enable row level security;
alter table contractor_links enable row level security;
alter table contractor_docs enable row level security;
alter table workers enable row level security;
alter table selfdec_answers enable row level security;
alter table worker_links enable row level security;
alter table worker_certs enable row level security;
alter table cert_reviews enable row level security;
alter table lsr_flags enable row level security;
alter table flag_acks enable row level security;
alter table teams enable row level security;
alter table team_members enable row level security;
alter table jobs enable row level security;
alter table permits enable row level security;
alter table checkins enable row level security;
alter table health_checks enable row level security;
alter table closeouts enable row level security;
alter table findings enable row level security;
alter table incidents enable row level security;
alter table notifications enable row level security;
alter table push_subs enable row level security;
alter table audit_log enable row level security;

-- องค์กร
create policy co_read on scg_companies for select using (id=any(my_cos()) or is_owner());
create policy co_owner on scg_companies for all using (is_owner()) with check (is_owner());
create policy grp_read on install_groups for select using (scg_company_id=any(my_cos()));
create policy grp_write on install_groups for all using (is_safety(scg_company_id)) with check (is_safety(scg_company_id));
create policy proj_read on projects for select using (scg_company_id=any(my_cos()));
create policy proj_write on projects for all using (is_safety(scg_company_id)) with check (is_safety(scg_company_id));
create policy jt_read on job_types for select using (scg_company_id=any(my_cos()));
create policy jt_write on job_types for all using (is_safety(scg_company_id)) with check (is_safety(scg_company_id));
create policy set_read on settings for select using (auth.uid() is not null and (scg_company_id is null or scg_company_id=any(my_cos())));
create policy set_write on settings for all using (scg_company_id is not null and is_safety(scg_company_id)) with check (scg_company_id is not null and is_safety(scg_company_id));

-- ผู้ใช้: เห็นตัวเอง · SCG เห็นคนในบริษัทเดียวกันและผู้ใช้ผู้รับเหมาที่เชื่อมอยู่ · ผู้รับเหมาเห็นคนในบริษัทตัวเอง + ผู้ติดต่อ SCG
create policy prof_read on profiles for select using (
  id=auth.uid()
  or (is_scg() and (scg_company_ids && my_cos() or (contractor_id is not null and can_see_contractor(contractor_id))))
  or (is_contractor() and (contractor_id=my_contractor() or (role in ('installation_consultant','ic_qc_manager','safety_admin','purchasing') and scg_company_ids && my_cos())))
  or (is_owner() and role='safety_admin'));
create policy inv_read on invites for select using (
  (is_scg() and scg_company_ids && my_cos()) or (contractor_id is not null and contractor_id=my_contractor()) or is_owner());

-- ผู้รับเหมา
create policy ctr_read on contractors for select using (can_see_contractor(id));
create policy ctr_update on contractors for update using (id=my_contractor() and my_role()='contractor_admin') with check (id=my_contractor());
create policy cl_read on contractor_links for select using (contractor_id=my_contractor() or has_co(scg_company_id));
create policy cd_read on contractor_docs for select using (can_see_contractor(contractor_id));
create policy cd_ins on contractor_docs for insert with check (contractor_id=my_contractor() and my_role()='contractor_admin');
create policy cd_del on contractor_docs for delete using (contractor_id=my_contractor() and my_role()='contractor_admin');

create policy w_read on workers for select using (contractor_id=my_contractor() or can_see_worker(id));
create policy w_ins on workers for insert with check (contractor_id=my_contractor() and my_role()='contractor_admin');
create policy w_upd on workers for update using (contractor_id=my_contractor() and my_role()='contractor_admin') with check (contractor_id=my_contractor());
create policy sd_rw on selfdec_answers for all using (exists(select 1 from workers w where w.id=worker_id and w.contractor_id=my_contractor() and my_role()='contractor_admin'))
  with check (exists(select 1 from workers w where w.id=worker_id and w.contractor_id=my_contractor() and my_role()='contractor_admin'));
create policy wl_read on worker_links for select using (has_co(scg_company_id) or exists(select 1 from workers w where w.id=worker_id and w.contractor_id=my_contractor()));
create policy wc_read on worker_certs for select using (can_see_worker(worker_id));
create policy wc_ins on worker_certs for insert with check (exists(select 1 from workers w where w.id=worker_id and w.contractor_id=my_contractor()) and my_role()='contractor_admin');
create policy cr_read on cert_reviews for select using (has_co(scg_company_id) or exists(select 1 from worker_certs c join workers w on w.id=c.worker_id where c.id=cert_id and w.contractor_id=my_contractor()));
create policy lf_read on lsr_flags for select using (is_scg() and can_see_contractor(contractor_id) or contractor_id=my_contractor());
create policy fa_read on flag_acks for select using (has_co(scg_company_id));

create policy t_read on teams for select using (contractor_id=my_contractor() or (is_scg() and can_see_contractor(contractor_id)));
create policy t_write on teams for all using (contractor_id=my_contractor() and my_role()='contractor_admin') with check (contractor_id=my_contractor() and my_role()='contractor_admin');
create policy tm_read on team_members for select using (exists(select 1 from teams t where t.id=team_id and (t.contractor_id=my_contractor() or (is_scg() and can_see_contractor(t.contractor_id)))));
create policy tm_write on team_members for all using (exists(select 1 from teams t where t.id=team_id and t.contractor_id=my_contractor() and my_role()='contractor_admin'))
  with check (exists(select 1 from teams t where t.id=team_id and t.contractor_id=my_contractor() and my_role()='contractor_admin'));

-- งาน
create policy j_read on jobs for select using (can_see_job(id));
create policy pm_read on permits for select using (can_see_job(job_id));
create policy ci_read on checkins for select using (can_see_job(job_id));
create policy hc_read on health_checks for select using (exists(select 1 from checkins c join jobs j on j.id=c.job_id where c.id=checkin_id and
  ((my_role()='contractor_admin' and j.contractor_id=my_contractor()) or is_safety(j.scg_company_id))));
create policy co2_read on closeouts for select using (can_see_job(job_id));
create policy f_read on findings for select using (can_see_job(job_id));
create policy inc_read on incidents for select using (has_co(scg_company_id) or (contractor_id is not null and contractor_id=my_contractor()) or reported_by=auth.uid());
create policy n_read on notifications for select using (to_id=auth.uid());
create policy ps_rw on push_subs for all using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy al_read on audit_log for select using (scg_company_id is not null and is_safety(scg_company_id));

-- สิทธิ์พื้นฐานของบทบาท (Supabase มีให้แล้ว · ใส่ซ้ำเผื่อฐานข้อมูลอื่น)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on app_secrets from anon, authenticated;
revoke insert, update, delete on audit_log, notifications, permits, checkins, health_checks, closeouts, findings, incidents,
  worker_links, cert_reviews, lsr_flags, flag_acks, contractor_links, jobs, profiles, invites, selfdec_answers, scg_companies from authenticated;
revoke insert, delete on contractors from authenticated;
grant insert, update, delete on scg_companies to authenticated;   -- ผ่าน policy co_owner เท่านั้น
grant usage, select on all sequences in schema public to authenticated;
