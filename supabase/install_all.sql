-- SafeStart v2 · ติดตั้งทั้งหมดในไฟล์เดียว (ล้างของเดิม + สร้างระบบ + ค่าตั้งต้น) · ผู้ดูแลระบบ: CHANGE_ME@scg.com
-- SafeStart · ล้างระบบทั้งหมดเพื่อติดตั้งใหม่ (ข้อมูลในระบบหายทั้งหมด · บัญชีผู้ใช้ใน Authentication ยังอยู่)
-- ใช้เมื่อเคยติดตั้งรุ่นก่อน แล้วจะติดตั้ง v2: รันไฟล์นี้ → schema.sql → seed.sql
drop trigger if exists on_auth_user on auth.users;
do $$ declare p record; begin
  for p in select policyname from pg_policies where schemaname='storage' and tablename='objects' loop
    execute format('drop policy if exists %I on storage.objects', p.policyname);
  end loop;
  begin alter publication supabase_realtime drop table jobs, permits, checkins, closeouts, findings, notifications, worker_links, incidents; exception when others then null; end;
end $$;
drop schema if exists public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on all tables in schema public to postgres, anon, authenticated, service_role;
grant all on all routines in schema public to postgres, anon, authenticated, service_role;
grant all on all sequences in schema public to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on routines to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;
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
-- =====================================================================
-- 7) ฟังก์ชันที่หน้าเว็บเรียก (ทุกกติกาตรวจที่นี่ แก้หน้าเว็บก็เลี่ยงไม่ได้)
-- =====================================================================

create or replace function need(ok boolean, msg text) returns void language plpgsql as $$
begin if not coalesce(ok,false) then raise exception '%', msg using errcode='P0001'; end if; end $$;

-- ---------- บัญชี ----------
create or replace function update_me(p_name text, p_phone text) returns void language sql security definer set search_path=public as
$$ update profiles set full_name=nullif(trim(p_name),''), phone=nullif(trim(p_phone),'') where id=auth.uid() $$;

create or replace function accept_pdpa(p_version text) returns void language plpgsql security definer set search_path=public as $$
begin
  update profiles set pdpa_version=p_version, pdpa_at=now() where id=auth.uid();
  perform audit(null,'pdpa_accept','profiles',auth.uid(),jsonb_build_object('version',p_version));
end $$;

create or replace function line_link_code() returns text language plpgsql security definer set search_path=public as $$
declare c text := upper(substr(encode(extensions.gen_random_bytes(4),'hex'),1,6));
begin update profiles set line_link_code=c where id=auth.uid(); return c; end $$;

-- เรียกจาก Apps Script (service key) เมื่อผู้ใช้พิมพ์รหัสใน LINE
create or replace function link_line(p_code text, p_line_user text) returns text language plpgsql security definer set search_path=public as $$
declare n text;
begin
  update profiles set line_user_id=p_line_user, line_link_code=null where line_link_code=upper(trim(p_code)) returning coalesce(full_name,email) into n;
  return n;
end $$;
revoke execute on function link_line(text,text) from anon, authenticated;

-- เชิญผู้ใช้ (ใครเชิญใครได้ตรวจที่นี่)
create or replace function invite_user(p_email text, p_name text, p_role text, p_cos uuid[] default '{}', p_contractor uuid default null) returns void language plpgsql security definer set search_path=public as $$
declare e text := lower(trim(p_email)); r text := my_role(); ok boolean := false; pr profiles;
begin
  perform need(e ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$','อีเมลไม่ถูกต้อง');
  if p_role in ('team_lead','contractor_admin') then
    perform need(p_contractor is not null,'ต้องระบุบริษัทผู้รับเหมา');
    ok := (r='contractor_admin' and p_contractor=my_contractor())
      or (r in ('purchasing','safety_admin') and exists(select 1 from contractor_links where contractor_id=p_contractor and scg_company_id=any(my_cos())));
    p_cos := '{}';
  elsif p_role='safety_admin' and is_owner() then ok := cardinality(p_cos)>0;
  else
    ok := r='safety_admin' and cardinality(p_cos)>0 and p_cos <@ my_cos()
      and p_role in ('installation_consultant','purchasing','ic_qc_manager','ms_manager','ms_director','safety_admin','executive');
    p_contractor := null;
  end if;
  perform need(ok,'คุณไม่มีสิทธิ์เชิญผู้ใช้บทบาทนี้');
  select * into pr from profiles where email=e;
  if found then
    perform need(pr.role in ('pending',p_role) or (pr.role not in ('team_lead','contractor_admin') and p_role not in ('team_lead','contractor_admin')),
      'อีเมลนี้มีบัญชีอยู่แล้วในบทบาทอื่น');
    update profiles set role=p_role, full_name=coalesce(full_name,nullif(p_name,'')), active=true,
      scg_company_ids=(select coalesce(array_agg(distinct x),'{}') from unnest(scg_company_ids||p_cos) x),
      contractor_id=coalesce(p_contractor,contractor_id) where id=pr.id;
  end if;
  insert into invites(email,full_name,role,scg_company_ids,contractor_id,invited_by) values(e,nullif(p_name,''),p_role,p_cos,p_contractor,auth.uid())
  on conflict (email) do update set full_name=excluded.full_name, role=excluded.role,
    scg_company_ids=(select coalesce(array_agg(distinct x),'{}') from unnest(invites.scg_company_ids||excluded.scg_company_ids) x),
    contractor_id=excluded.contractor_id, invited_by=excluded.invited_by;
  perform audit(p_cos[1],'invite','profiles',null,jsonb_build_object('email',e,'role',p_role));
end $$;

-- ปรับบทบาท/ปิดใช้งาน
create or replace function set_user(p_id uuid, p_role text, p_active boolean) returns void language plpgsql security definer set search_path=public as $$
declare u profiles; r text := my_role();
begin
  select * into u from profiles where id=p_id; perform need(found,'ไม่พบผู้ใช้');
  perform need(p_id<>auth.uid(),'แก้สิทธิ์ของตัวเองไม่ได้');
  if u.role in ('team_lead','contractor_admin') then
    perform need((r='contractor_admin' and u.contractor_id=my_contractor() and p_role in ('team_lead','contractor_admin'))
      or (r='safety_admin' and can_see_contractor(u.contractor_id) and p_role in ('team_lead','contractor_admin')),'ไม่มีสิทธิ์');
  else
    perform need(r='safety_admin' and u.scg_company_ids && my_cos() and p_role not in ('team_lead','contractor_admin','pending'),'ไม่มีสิทธิ์');
  end if;
  update profiles set role=p_role, active=p_active where id=p_id;
  perform audit((my_cos())[1],'set_user','profiles',p_id,jsonb_build_object('role',p_role,'active',p_active));
end $$;

-- ผู้ดูแลระบบสร้างบริษัท SCG + เชิญ Safety Admin คนแรก
create or replace function owner_create_company(p_name text, p_short text, p_color text, p_admin_email text, p_admin_name text) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
  perform need(is_owner(),'เฉพาะผู้ดูแลระบบ');
  insert into scg_companies(name,short,color) values(p_name,p_short,coalesce(p_color,'#0B6B4A')) returning id into cid;
  if p_admin_email is not null and p_admin_email<>'' then perform invite_user(p_admin_email,p_admin_name,'safety_admin',array[cid]); end if;
  return cid;
end $$;

-- ---------- ผู้รับเหมา ----------
create or replace function contractor_flags(p_contractor uuid) returns jsonb language sql stable security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'rule',f.rule,'kind',f.kind,'step',f.step,'penalty',f.penalty,'date',f.occurred_on,
    'company',c.name,'worker',w.full_name) order by f.occurred_on desc),'[]')
  from lsr_flags f join scg_companies c on c.id=f.scg_company_id left join workers w on w.id=f.worker_id
  where f.contractor_id=p_contractor and f.occurred_on>=bkk_today()-365 $$;
create or replace function worker_flags(p_worker uuid) returns jsonb language sql stable security definer set search_path=public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'rule',f.rule,'kind',f.kind,'step',f.step,'penalty',f.penalty,'date',f.occurred_on,'company',c.name,
    'forever',f.ban_forever) order by f.occurred_on desc),'[]')
  from lsr_flags f join scg_companies c on c.id=f.scg_company_id
  where f.worker_id=p_worker or (f.worker_id in (select w2.id from workers w1 join workers w2 on w2.id_hash=w1.id_hash where w1.id=p_worker and w1.id_hash is not null)) $$;

-- Purchasing ค้นบริษัทด้วยเลขผู้เสียภาษี (เห็นได้แม้ยังไม่เชื่อม)
create or replace function find_contractor(p_tax text) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c contractors;
begin
  perform need(my_role() in ('purchasing','safety_admin'),'เฉพาะ Purchasing หรือ Safety');
  select * into c from contractors where tax_id=trim(p_tax);
  if not found then return null; end if;
  return jsonb_build_object('id',c.id,'name',c.name,'contact_name',c.contact_name,'contact_phone',c.contact_phone,
    'linked',(select coalesce(jsonb_agg(jsonb_build_object('company',s.name,'status',l.status)),'[]') from contractor_links l join scg_companies s on s.id=l.scg_company_id where l.contractor_id=c.id),
    'flags',contractor_flags(c.id));
end $$;

create or replace function register_contractor(p_co uuid, p_name text, p_tax text, p_contact text, p_phone text, p_email text,
  p_vendor_code text, p_approve boolean default true) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
  perform need(role_in(p_co,array['purchasing','safety_admin']),'เฉพาะ Purchasing หรือ Safety ของบริษัทนี้');
  perform need(p_tax ~ '^[0-9]{13}$','เลขผู้เสียภาษีต้องมี 13 หลัก');
  select id into cid from contractors where tax_id=p_tax;
  if cid is null then
    insert into contractors(name,tax_id,contact_name,contact_phone,email,created_by) values(trim(p_name),p_tax,p_contact,p_phone,p_email,auth.uid()) returning id into cid;
  end if;
  insert into contractor_links(scg_company_id,contractor_id,status,vendor_code,vendor_approved,decided_by,decided_at)
  values(p_co,cid,case when p_approve then 'approved' else 'pending' end,nullif(trim(p_vendor_code),''),p_approve,
    case when p_approve then auth.uid() end,case when p_approve then now() end)
  on conflict (scg_company_id,contractor_id) do update set vendor_code=coalesce(excluded.vendor_code,contractor_links.vendor_code);
  insert into flag_acks(flag_id,scg_company_id,ack_by,context) select f.id,p_co,auth.uid(),'link' from lsr_flags f where f.contractor_id=cid on conflict do nothing;
  perform audit(p_co,'contractor_link','contractors',cid,jsonb_build_object('approve',p_approve));
  return cid;
end $$;

create or replace function decide_contractor(p_co uuid, p_contractor uuid, p_status text, p_vendor_code text, p_note text) returns void language plpgsql security definer set search_path=public as $$
begin
  perform need(role_in(p_co,array['purchasing','safety_admin']),'เฉพาะ Purchasing หรือ Safety');
  perform need(p_status in ('pending','approved','suspended'),'สถานะไม่ถูกต้อง');
  update contractor_links set status=p_status, vendor_approved=(p_status='approved'), vendor_code=coalesce(nullif(trim(p_vendor_code),''),vendor_code),
    note=p_note, decided_by=auth.uid(), decided_at=now() where scg_company_id=p_co and contractor_id=p_contractor;
  perform need(found,'บริษัทนี้ยังไม่อยู่ในทะเบียน');
  perform notify_many(contractor_admins(p_contractor),p_co,'contractor',
    case p_status when 'approved' then 'อนุมัติให้รับงานแล้ว' when 'suspended' then 'บริษัทถูกพักรับงาน' else 'สถานะบริษัทเปลี่ยน' end||' · '||(select name from scg_companies where id=p_co),
    p_note,'contractors',p_contractor,p_status='suspended',p_status='suspended');
  perform audit(p_co,'contractor_status','contractors',p_contractor,jsonb_build_object('status',p_status,'note',p_note));
end $$;

create or replace function ack_flags(p_co uuid, p_flags uuid[], p_context text) returns void language sql security definer set search_path=public as $$
  insert into flag_acks(flag_id,scg_company_id,ack_by,context) select x,p_co,auth.uid(),p_context from unnest(p_flags) x where has_co(p_co) on conflict do nothing $$;

-- ---------- ช่าง ----------
create or replace function request_worker_links(p_co uuid, p_workers uuid[]) returns int language plpgsql security definer set search_path=public as $$
declare n int;
begin
  perform need(my_role()='contractor_admin','เฉพาะผู้ดูแลบริษัทผู้รับเหมา');
  perform need(exists(select 1 from contractor_links where contractor_id=my_contractor() and scg_company_id=p_co and status<>'suspended'),'บริษัทของคุณยังไม่อยู่ในทะเบียนของบริษัทนี้ หรือถูกพัก');
  insert into worker_links(scg_company_id,worker_id,requested_by)
  select p_co,w.id,auth.uid() from workers w where w.id=any(p_workers) and w.contractor_id=my_contractor()
  on conflict (scg_company_id,worker_id) do update set status=case when worker_links.status='rejected' then 'pending' else worker_links.status end;
  get diagnostics n = row_count;
  perform notify_many(co_users(p_co,array['purchasing']),p_co,'worker','คำขอให้ช่างเข้าทำงาน '||n||' คน · '||(select name from contractors where id=my_contractor()),
    'ตรวจตัวบุคคลและอนุมัติในกล่องงาน','contractors',my_contractor(),false,true);
  return n;
end $$;

-- ตรวจเลขบัตรไทย
create or replace function thai_id_ok(p text) returns boolean language plpgsql immutable as $$
declare s int := 0;
begin
  if p !~ '^[0-9]{13}$' then return false; end if;
  for i in 1..12 loop s := s + substr(p,i,1)::int * (14-i); end loop;
  return (11 - s % 11) % 10 = substr(p,13,1)::int;
end $$;

-- SCG ตรวจตัวบุคคลกับบัตรจริง: เก็บเลขท้าย 4 หลัก + hash (อ่านกลับไม่ได้) แล้วลบรูปบัตร · ตรวจครั้งเดียวใช้ทั้งกลุ่ม
create or replace function verify_worker_id(p_worker uuid, p_idno text, p_co uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare w workers; n text := regexp_replace(coalesce(p_idno,''),'[\s-]','','g'); h text; dup jsonb;
begin
  perform need(role_in(p_co,array['purchasing','installation_consultant','safety_admin']),'ไม่มีสิทธิ์ตรวจตัวบุคคล');
  select * into w from workers where id=p_worker; perform need(found and can_see_worker(p_worker),'ไม่พบช่าง');
  perform need(length(n)>=8,'ใส่เลขบัตรให้ครบ');
  if w.nationality='th' and not w.foreign_worker then perform need(thai_id_ok(n),'เลขบัตรประชาชนไม่ถูกต้อง (ตรวจหลักสุดท้ายไม่ผ่าน)'); end if;
  h := encode(extensions.hmac(upper(n),(select value from app_secrets where key='id_salt'),'sha256'),'hex');
  select coalesce(jsonb_agg(jsonb_build_object('worker',x.full_name,'contractor',c.name,'flags',worker_flags(x.id))),'[]') into dup
    from workers x join contractors c on c.id=x.contractor_id where x.id_hash=h and x.id<>p_worker;
  update workers set id_last4=right(n,4), id_hash=h, id_verified_by=auth.uid(), id_verified_company=p_co, id_verified_at=now(), id_image_path=null where id=p_worker;
  perform audit(p_co,'verify_id','workers',p_worker,jsonb_build_object('last4',right(n,4),'dup',jsonb_array_length(dup)));
  return jsonb_build_object('duplicates',dup,'flags',worker_flags(p_worker));
end $$;

create or replace function decide_worker(p_co uuid, p_worker uuid, p_approve boolean, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare w workers;
begin
  perform need(role_in(p_co,array['purchasing','installation_consultant','safety_admin']),'ไม่มีสิทธิ์อนุมัติช่าง');
  select * into w from workers where id=p_worker;
  perform need(exists(select 1 from worker_links where worker_id=p_worker and scg_company_id=p_co),'ช่างคนนี้ยังไม่ได้ขอเข้าทำงานกับบริษัทนี้');
  if p_approve then perform need(w.id_verified_at is not null,'ต้องตรวจตัวบุคคลก่อนอนุมัติ');
  else perform need(coalesce(trim(p_note),'')<>'','ใส่เหตุผลที่ไม่อนุมัติ'); end if;
  update worker_links set status=case when p_approve then 'approved' else 'rejected' end, decided_by=auth.uid(), decided_at=now(), note=p_note
   where worker_id=p_worker and scg_company_id=p_co;
  insert into flag_acks(flag_id,scg_company_id,ack_by,context) select (f->>'id')::uuid,p_co,auth.uid(),'worker' from jsonb_array_elements(worker_flags(p_worker)) f on conflict do nothing;
  perform notify_many(contractor_admins(w.contractor_id),p_co,'worker',(case when p_approve then 'อนุมัติช่าง ' else 'ไม่อนุมัติช่าง ' end)||w.full_name||' · '||(select name from scg_companies where id=p_co),
    p_note,'workers',p_worker,false,false);
  perform audit(p_co,'decide_worker','workers',p_worker,jsonb_build_object('approve',p_approve,'note',p_note));
end $$;

create or replace function review_cert(p_co uuid, p_cert uuid, p_approve boolean, p_note text) returns void language plpgsql security definer set search_path=public as $$
begin
  perform need(role_in(p_co,array['purchasing','installation_consultant','safety_admin']),'ไม่มีสิทธิ์ตรวจ cert');
  perform need(exists(select 1 from worker_certs c where c.id=p_cert and can_see_worker(c.worker_id)),'ไม่พบเอกสาร');
  insert into cert_reviews(cert_id,scg_company_id,status,note,reviewed_by) values(p_cert,p_co,case when p_approve then 'approved' else 'rejected' end,p_note,auth.uid())
  on conflict (cert_id,scg_company_id) do update set status=excluded.status, note=excluded.note, reviewed_by=excluded.reviewed_by, reviewed_at=now();
  perform audit(p_co,'review_cert','worker_certs',p_cert,jsonb_build_object('approve',p_approve));
end $$;

-- Self-declaration ปีละครั้ง (ผู้ดูแลบริษัทผู้รับเหมากรอกร่วมกับช่าง)
create or replace function submit_selfdec(p_worker uuid, p_answers jsonb) returns text language plpgsql security definer set search_path=public as $$
declare yes boolean; n int := jsonb_array_length(coalesce(setting(null,'selfdec')->'items','[]')); st text;
begin
  perform need(my_role()='contractor_admin' and exists(select 1 from workers where id=p_worker and contractor_id=my_contractor()),'เฉพาะผู้ดูแลบริษัทของช่างคนนี้');
  perform need((select count(*) from jsonb_object_keys(p_answers))>=n,'ตอบให้ครบทุกข้อ');
  yes := exists(select 1 from jsonb_each_text(p_answers) where value='yes');
  st := case when yes then 'need_doctor' else 'ok' end;
  insert into selfdec_answers(worker_id,answers,updated_by) values(p_worker,p_answers,auth.uid())
  on conflict (worker_id) do update set answers=excluded.answers, signed_at=now(), updated_by=excluded.updated_by;
  update workers set selfdec_status=st, selfdec_at=now(), selfdec_until=bkk_today()+365, selfdec_doctor_path=null, selfdec_reviewed_by=null where id=p_worker;
  return st;
end $$;

create or replace function submit_selfdec_doctor(p_worker uuid, p_path text) returns void language plpgsql security definer set search_path=public as $$
declare w workers; l record;
begin
  select * into w from workers where id=p_worker;
  perform need(my_role()='contractor_admin' and w.contractor_id=my_contractor(),'เฉพาะผู้ดูแลบริษัทของช่างคนนี้');
  perform need(w.selfdec_status in ('need_doctor','doctor_submitted'),'ช่างคนนี้ไม่ต้องใช้ใบรับรองแพทย์');
  perform need(p_path is not null,'แนบใบรับรองแพทย์');
  update workers set selfdec_status='doctor_submitted', selfdec_doctor_path=p_path where id=p_worker;
  for l in select scg_company_id from worker_links where worker_id=p_worker loop
    perform notify_many(co_users(l.scg_company_id,array['safety_admin']),l.scg_company_id,'selfdec','ใบรับรองแพทย์รอรับรอง: '||w.full_name,'Self-declaration ตอบ "เคย" บางข้อ','workers',p_worker,false,true);
  end loop;
end $$;

create or replace function review_selfdec_doctor(p_worker uuid, p_ok boolean, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare w workers;
begin
  select * into w from workers where id=p_worker;
  perform need(my_role()='safety_admin' and exists(select 1 from worker_links l where l.worker_id=p_worker and l.scg_company_id=any(my_cos())),'เฉพาะ Safety ของบริษัทที่ช่างทำงานด้วย');
  perform need(w.selfdec_status='doctor_submitted','ยังไม่มีใบรับรองแพทย์ให้ตรวจ');
  update workers set selfdec_status=case when p_ok then 'doctor_ok' else 'need_doctor' end, selfdec_reviewed_by=auth.uid() where id=p_worker;
  perform notify_many(contractor_admins(w.contractor_id),null,'selfdec',(case when p_ok then 'รับรองใบแพทย์แล้ว: ' else 'ใบแพทย์ไม่ผ่าน: ' end)||w.full_name,p_note,'workers',p_worker,false,not p_ok);
  perform audit((my_cos())[1],'review_selfdec','workers',p_worker,jsonb_build_object('ok',p_ok));
end $$;

-- ช่างคนนี้เข้างานของบริษัท co ได้ไหม (คืนรายการเหตุผลที่ไม่ได้)
create or replace function worker_blockers(p_worker uuid, p_co uuid, p_hazards text[], p_on date, p_wah boolean) returns text[] language plpgsql stable security definer set search_path=public as $$
declare w workers; l worker_links; out text[] := '{}'; req text[]; hc jsonb := setting(p_co,'hazard_certs'); c text; names jsonb := setting(p_co,'cert_types');
begin
  select * into w from workers where id=p_worker;
  if not found then return array['ไม่พบช่าง']; end if;
  select * into l from worker_links where worker_id=p_worker and scg_company_id=p_co;
  if l.status is null then out:=out||'ยังไม่ได้ขอเข้าทำงานกับบริษัทนี้'::text;
  elsif l.status='pending' then out:=out||'รออนุมัติ'::text;
  elsif l.status='rejected' then out:=out||'ไม่ได้รับอนุมัติ'::text; end if;
  if not w.active then out:=out||'ปิดใช้งาน'::text; end if;
  if w.id_verified_at is null then out:=out||'ยังไม่ตรวจตัวบุคคล'::text; end if;
  if l.banned_forever then out:=out||'ห้ามทำงานตลอดชีพ (LSR)'::text;
  elsif l.banned_until>=p_on then out:=out||('ห้ามทำงานถึง '||to_char(l.banned_until,'DD/MM/YYYY')||' (LSR)'); end if;
  if w.foreign_worker and (w.work_permit_expiry is null or w.work_permit_expiry<p_on) then out:=out||'Work permit หมดอายุ'::text; end if;
  if coalesce((setting(p_co,'rules')->>'enforce_certs')::boolean,true) then
    select coalesce(array_agg(distinct x),'{}') into req from (
      select jsonb_array_elements_text(coalesce(hc->'all','[]')) x
      union select jsonb_array_elements_text(coalesce(hc->h,'[]')) from unnest(p_hazards) h where h<>'wah' or p_wah) q;
    foreach c in array req loop
      if not exists(select 1 from worker_certs wc join cert_reviews r on r.cert_id=wc.id and r.scg_company_id=p_co and r.status='approved'
         where wc.worker_id=p_worker and wc.cert_type=c and (wc.expires_on is null or wc.expires_on>=p_on)) then
        out:=out||('ขาด '||coalesce(names->>c,c));
      end if;
    end loop;
  end if;
  if p_wah then
    if w.birth_date is null then out:=out||'ไม่มีวันเกิด (งานที่สูงต้องอายุ 18+)'::text;
    elsif age_on(w.birth_date,p_on)<18 then out:=out||'อายุต่ำกว่า 18 ปี ห้ามทำงานที่สูง'::text; end if;
    if w.selfdec_status not in ('ok','doctor_ok') or w.selfdec_until is null or w.selfdec_until<p_on then
      out:=out||(case when w.selfdec_status in ('need_doctor','doctor_submitted') then 'รอใบรับรองแพทย์ (Self-declaration)' else 'Self-declaration หมดอายุ/ยังไม่ทำ' end);
    end if;
  end if;
  return out;
end $$;

-- บันทึกโทษ LSR (รอบนี้: Safety บันทึกตรง · รอบถัดไปมีเคสสอบสวนร่วม 10 วัน)
create or replace function record_lsr(p_co uuid, p_worker uuid, p_contractor uuid, p_job uuid, p_rule int, p_kind text, p_note text, p_on date default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare cid uuid := p_contractor; prev int := 0; st int; pen text; days int; forever boolean := false; fid uuid;
begin
  perform need(is_safety(p_co),'เฉพาะ SCG Safety ของบริษัทนี้');
  perform need(p_rule between 1 and 9,'เลือกกฎข้อที่ฝ่าฝืน');
  if p_worker is not null then select contractor_id into cid from workers where id=p_worker; end if;
  perform need(cid is not null,'ระบุช่างหรือบริษัท');
  if p_kind is null then p_kind := case when p_rule>=7 then 'driving' else 'working' end; end if;
  if p_worker is not null then
    select count(*) into prev from lsr_flags where worker_id=p_worker and scg_company_id=p_co and kind=p_kind and occurred_on>=coalesce(p_on,bkk_today())-365;
    st := prev+1;
    if p_kind='working' then
      if st=1 then pen:='ห้ามทำงานกับบริษัท 7 วัน'; days:=7; else pen:='ห้ามทำงานตลอดชีพ'; forever:=true; st:=2; end if;
    else
      if st=1 then pen:='ห้ามทำงานกับบริษัท 3 วัน'; days:=3; elsif st=2 then pen:='ห้ามทำงานกับบริษัท 7 วัน'; days:=7; else pen:='ห้ามทำงานตลอดชีพ'; forever:=true; st:=3; end if;
    end if;
    insert into worker_links(scg_company_id,worker_id,status) values(p_co,p_worker,'rejected') on conflict do nothing;
    update worker_links set banned_forever=banned_forever or forever,
      banned_until=case when forever then banned_until else greatest(coalesce(banned_until,'1900-01-01'),coalesce(p_on,bkk_today())+days-1) end
      where worker_id=p_worker and scg_company_id=p_co;
  else
    select count(distinct occurred_on) into prev from lsr_flags where contractor_id=cid and worker_id is null and scg_company_id=p_co and occurred_on>=coalesce(p_on,bkk_today())-365;
    st := least(prev+1,3);
    pen := case st when 1 then 'หนังสือแจ้งให้จัดทำมาตรการป้องกัน + ปรับไม่เกิน 5,000 บาท' when 2 then 'หนังสือแจ้ง + ปรับ 10,000–20,000 บาท'
      else 'หนังสือแจ้ง + ปรับ 20,000–50,000 บาท และ/หรือพิจารณาหยุดจ้างงานไม่เกิน 6 เดือน' end;
  end if;
  insert into lsr_flags(scg_company_id,contractor_id,worker_id,job_id,rule,kind,step,penalty,ban_days,ban_forever,occurred_on,note,created_by)
  values(p_co,cid,p_worker,p_job,p_rule,p_kind,st,pen,days,forever,coalesce(p_on,bkk_today()),p_note,auth.uid()) returning id into fid;
  perform notify_many(contractor_admins(cid),p_co,'lsr','บันทึกโทษฝ่าฝืนกฎพิทักษ์ชีวิต ข้อ '||p_rule||coalesce(' · '||(select full_name from workers where id=p_worker),''),pen,'lsr_flags',fid,true,true);
  perform audit(p_co,'record_lsr','lsr_flags',fid,jsonb_build_object('rule',p_rule,'step',st,'penalty',pen));
  return jsonb_build_object('id',fid,'step',st,'penalty',pen);
end $$;

-- ---------- แผนงาน / ใบอนุญาต ----------
create or replace function contractor_blockers(p_contractor uuid, p_co uuid) returns text[] language plpgsql stable security definer set search_path=public as $$
declare l contractor_links; out text[] := '{}'; t text;
begin
  select * into l from contractor_links where contractor_id=p_contractor and scg_company_id=p_co;
  if l.status is null then return array['บริษัทยังไม่อยู่ในทะเบียน']; end if;
  if l.status='suspended' then out:=out||'บริษัทถูกพักรับงาน'::text; elsif l.status='pending' then out:=out||'บริษัทยังไม่ได้รับอนุมัติ'::text; end if;
  if coalesce((setting(p_co,'rules')->>'enforce_docs')::boolean,false) then
    foreach t in array array['registration','sso','jp'] loop
      if not exists(select 1 from contractor_docs d where d.contractor_id=p_contractor and d.doc_type=t and (d.expires_on is null or d.expires_on>=bkk_today())) then
        out:=out||('เอกสารบริษัทหมดอายุ/ยังไม่ส่ง: '||coalesce(setting(p_co,'doc_types')->>t,t));
      end if;
    end loop;
  end if;
  return out;
end $$;

create or replace function plan_hazards(p_types uuid[], a jsonb) returns text[] language sql stable security definer set search_path=public as $$
  select coalesce(array_agg(distinct h),'{}') from (
    select unnest(hazards) h from job_types where id=any(p_types)
    union select 'wah' where coalesce((a->>'height18')::boolean,false)
    union select 'hot' where coalesce((a->>'hot')::boolean,false)
    union select 'electric' where coalesce((a->>'electric')::boolean,false)
    union select 'confined' where coalesce((a->>'confined')::boolean,false)
    union select 'lifting' where coalesce((a->>'lifting')::boolean,false)
    union select 'excavation' where coalesce((a->>'excavation')::boolean,false)
    union select 'chemical' where coalesce((a->>'chemical')::boolean,false)) q $$;

create or replace function submit_plan(p_job uuid, p_team uuid, p_answers jsonb, p_setup_method text default null, p_setup_workers uuid[] default '{}') returns jsonb language plpgsql security definer set search_path=public as $$
declare j jobs; hz text[]; rk text; st text; late boolean := false; dl text; bl text[]; pid uuid;
begin
  select * into j from jobs where id=p_job;
  perform need(found and j.contractor_id=my_contractor() and my_role()='contractor_admin','เฉพาะผู้ดูแลบริษัทผู้รับเหมาของงานนี้');
  perform need(j.status in ('planned','permit_pending','approved'),'งานนี้ยื่นแผนใหม่ไม่ได้ (สถานะ: '||j.status||')');
  perform need(not exists(select 1 from checkins where job_id=p_job and not voided),'งานนี้เริ่ม check-in แล้ว แก้แผนไม่ได้');
  perform need(exists(select 1 from teams where id=p_team and contractor_id=j.contractor_id),'เลือกทีม');
  bl := contractor_blockers(j.contractor_id,j.scg_company_id);
  perform need(cardinality(bl)=0,array_to_string(bl,' · '));
  hz := plan_hazards(j.job_type_ids,p_answers);
  if 'wah'=any(hz) then
    perform need(coalesce(p_answers->>'anchor','')<>'none','ไม่มีจุดยึดที่เหมาะสม = ห้ามทำงานที่สูง กรุณาติดต่อ IC ของโครงการ');
    perform need(coalesce(p_answers->>'anchor','') in ('existing','install'),'ระบุเรื่องจุดยึด/Lifeline');
    if p_answers->>'anchor'='install' then
      perform need(coalesce(p_setup_method,'')<>'','เลือกวิธีติดตั้งจุดยึด');
      perform need(cardinality(p_setup_workers)>0,'ระบุคนที่ขึ้นไปติดตั้งจุดยึด');
    end if;
  end if;
  rk := hazard_risk(hz);
  dl := coalesce(setting(j.scg_company_id,'sla')->>'permit_deadline','16:00');
  if rk='high' then late := bkk_now() > ((j.start_date-1)+dl::time); end if;
  st := case rk when 'high' then 'pending' else 'approved' end;
  update jobs set team_id=p_team, site_answers=p_answers, occupied=coalesce((p_answers->>'occupied')::boolean,occupied), hazards=hz,
    setup_method=case when p_answers->>'anchor'='install' then p_setup_method end,
    setup_worker_ids=case when p_answers->>'anchor'='install' then p_setup_workers else '{}' end,
    status=case when st='approved' then 'approved' else 'permit_pending' end where id=p_job;
  delete from permits where job_id=p_job;
  insert into permits(job_id,tier,status,late,submitted_by,decided_by,decided_at,note)
  values(p_job,rk,st,late,auth.uid(),case when st='approved' then auth.uid() end,case when st='approved' then now() end,
    case rk when 'low' then 'อนุมัติอัตโนมัติ (เสี่ยงต่ำ)' when 'med' then 'อนุมัติโดยผู้ดูแลบริษัทผู้รับเหมา (เสี่ยงกลาง)' end) returning id into pid;
  if rk='high' then
    perform notify_many(project_ics(j.project_id),j.scg_company_id,'permit','ใบอนุญาตเสี่ยงสูงรออนุมัติ '||j.po_no||case when late then ' (ยื่นช้า)' else '' end,
      (select name from projects where id=j.project_id)||' บ้าน '||coalesce(j.house_no,'')||' · เริ่ม '||to_char(j.start_date,'DD/MM'),'jobs',p_job,false,true);
  elsif rk='med' then
    perform notify_many(project_ics(j.project_id),j.scg_company_id,'permit','แจ้งให้ทราบ: งานเสี่ยงกลาง '||j.po_no||' อนุมัติโดยผู้รับเหมา',
      array_to_string(hz,', '),'jobs',p_job,false,false);
  end if;
  perform audit(j.scg_company_id,'submit_plan','jobs',p_job,jsonb_build_object('risk',rk,'late',late));
  return jsonb_build_object('risk',rk,'status',st,'late',late,'hazards',hz);
end $$;

create or replace function can_approve_job(jid uuid) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from jobs j join projects p on p.id=j.project_id where j.id=jid and has_co(j.scg_company_id) and
    (auth.uid() in (p.ic_id,p.backup_ic_id) or my_role() in ('ic_qc_manager','safety_admin'))) $$;

create or replace function decide_permit(p_permit uuid, p_approve boolean, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare pm permits; j jobs;
begin
  select * into pm from permits where id=p_permit; perform need(found,'ไม่พบใบอนุญาต');
  select * into j from jobs where id=pm.job_id;
  perform need(can_approve_job(j.id),'คุณไม่ใช่ผู้อนุมัติของโครงการนี้');
  perform need(pm.status='pending','ใบอนุญาตนี้ตัดสินแล้ว');
  if not p_approve then perform need(coalesce(trim(p_note),'')<>'','ใส่เหตุผลที่ตีกลับ'); end if;
  update permits set status=case when p_approve then 'approved' else 'rejected' end, decided_by=auth.uid(), decided_at=now(), note=p_note where id=p_permit;
  update jobs set status=case when p_approve then 'approved' else 'planned' end where id=j.id;
  perform notify_many(contractor_admins(j.contractor_id)||job_lead(j.id),j.scg_company_id,'permit',
    case when p_approve then 'อนุมัติแผนงาน '||j.po_no else 'แผนงาน '||j.po_no||' ถูกตีกลับ' end,p_note,'jobs',j.id,false,not p_approve);
  perform audit(j.scg_company_id,'decide_permit','permits',p_permit,jsonb_build_object('approve',p_approve,'note',p_note));
end $$;

-- นำเข้า PO (แถวที่หน้าเว็บจับคู่คอลัมน์แล้ว) · โครงการใหม่สร้างอัตโนมัติ
create or replace function import_jobs(p_co uuid, p_rows jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare r jsonb; i int := 0; ok int := 0; errs jsonb := '[]'; bad text[]; pid uuid; cid uuid; jts uuid[]; nm text; hz text[]; newp int := 0; gid uuid; sd date; ed date;
begin
  perform need(role_in(p_co,array['purchasing','safety_admin','ic_qc_manager','installation_consultant']),'ไม่มีสิทธิ์นำเข้า PO');
  for r in select * from jsonb_array_elements(p_rows) loop
    i := i+1; bad := '{}'; pid := null; cid := null; jts := '{}'; gid := null;
    if coalesce(r->>'po_no','')='' then bad := bad||'ไม่มีเลข PO'::text; end if;
    select l.contractor_id into cid from contractor_links l join contractors c on c.id=l.contractor_id
      where l.scg_company_id=p_co and (l.vendor_code=trim(r->>'contractor') or c.tax_id=trim(r->>'contractor') or c.name=trim(r->>'contractor')) limit 1;
    if cid is null then bad := bad||('ไม่พบผู้รับเหมา "'||coalesce(r->>'contractor','')||'" ในทะเบียน'); end if;
    for nm in select trim(x) from unnest(string_to_array(coalesce(r->>'job_types',''),',')) x where trim(x)<>'' loop
      if exists(select 1 from job_types where scg_company_id=p_co and name=nm) then
        jts := jts||(select id from job_types where scg_company_id=p_co and name=nm);
      else bad := bad||('ไม่พบประเภทงาน "'||nm||'"'); end if;
    end loop;
    if cardinality(jts)=0 and not exists(select 1 from unnest(bad) b where b like 'ไม่พบประเภทงาน%') then bad := bad||'ไม่มีประเภทงาน'::text; end if;
    begin sd := (r->>'start_date')::date; ed := coalesce(nullif(r->>'end_date','')::date,sd); exception when others then sd := null; end;
    if sd is null then bad := bad||'วันที่ผิดรูปแบบ (YYYY-MM-DD)'::text; elsif ed<sd then bad := bad||'วันจบก่อนวันเริ่ม'::text; end if;
    if coalesce(trim(r->>'project'),'')='' then bad := bad||'ไม่มีชื่อโครงการ'::text; end if;
    if cardinality(bad)>0 then errs := errs||jsonb_build_object('row',i,'po_no',r->>'po_no','errors',to_jsonb(bad)); continue; end if;
    select id into pid from projects where scg_company_id=p_co and name=trim(r->>'project');
    if pid is null then
      select group_id into gid from job_types where id=jts[1];
      insert into projects(scg_company_id,group_id,name,auto_created) values(p_co,gid,trim(r->>'project'),true) returning id into pid; newp := newp+1;
    end if;
    select coalesce(array_agg(distinct h),'{}') into hz from job_types, unnest(hazards) h where id=any(jts);
    insert into jobs(scg_company_id,project_id,contractor_id,po_no,job_type_ids,house_no,address,lat,lng,start_date,end_date,start_time,occupied,hazards,created_by)
    values(p_co,pid,cid,trim(r->>'po_no'),jts,r->>'house_no',r->>'address',nullif(r->>'lat','')::float8,nullif(r->>'lng','')::float8,sd,ed,
      coalesce(nullif(r->>'start_time','')::time,'08:00'),coalesce(r->>'occupied','') ~* '^(y|yes|1|true|ใช่|มี)',hz,auth.uid())
    on conflict (scg_company_id,po_no) do update set project_id=excluded.project_id, contractor_id=excluded.contractor_id, job_type_ids=excluded.job_type_ids,
      house_no=excluded.house_no, address=excluded.address, lat=coalesce(excluded.lat,jobs.lat), lng=coalesce(excluded.lng,jobs.lng),
      start_date=excluded.start_date, end_date=excluded.end_date, start_time=excluded.start_time, occupied=excluded.occupied,
      hazards=case when jobs.status='planned' then excluded.hazards else jobs.hazards end;
    ok := ok+1;
  end loop;
  perform audit(p_co,'import_jobs','jobs',null,jsonb_build_object('rows',i,'imported',ok,'new_projects',newp));
  return jsonb_build_object('imported',ok,'new_projects',newp,'errors',errs);
end $$;

create or replace function save_po_mapping(p_co uuid, p_map jsonb) returns void language plpgsql security definer set search_path=public as $$
begin
  perform need(role_in(p_co,array['purchasing','safety_admin','ic_qc_manager','installation_consultant']),'ไม่มีสิทธิ์');
  insert into settings(scg_company_id,key,value) values(p_co,'po_mapping',p_map) on conflict (scg_company_id,key) do update set value=excluded.value, updated_at=now();
end $$;

-- ---------- Safety Check-in ----------
create or replace function checklist_items(p_co uuid) returns table(code text, crit boolean, setup boolean, sec text, txt text) language sql stable security definer set search_path=public as $$
  select i->>'code', coalesce((i->>'crit')::boolean,false), coalesce((i->>'setup')::boolean,false), s->>'when', i->>'text'
  from jsonb_array_elements(coalesce(setting(p_co,'checklist'),'[]')) s, jsonb_array_elements(s->'items') i $$;

-- หมวดที่ใช้กับงานนี้
create or replace function job_sections(j jobs) returns text[] language sql stable as $$
  select array['all']||j.hazards||case when j.occupied then array['occupied'] else '{}'::text[] end
    ||case when coalesce((j.site_answers->>'ladder')::boolean,false) then array['ladder'] else '{}'::text[] end
    ||case when coalesce((j.site_answers->>'scaffold')::boolean,false) then array['scaffold'] else '{}'::text[] end $$;

create or replace function submit_checkin(p_job uuid, p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare j jobs; pm permits; p projects; d date := bkk_today(); ci uuid; tok text; late boolean; w uuid; bl text[]; nf int := 0; it record; a jsonb;
  wah uuid[]; wahs boolean; hr jsonb; hpass boolean; dist int; rad int; prevci checkins; sev text; due timestamptz; stg text := 'work'; setup_due timestamptz;
  setup_w uuid[] := '{}'; secs text[]; ok_codes int; wlv text; prob text[] := '{}'; lim int;
begin
  select * into j from jobs where id=p_job;
  perform need(found and j.contractor_id=my_contractor(),'ไม่พบงานของบริษัทคุณ');
  perform need(my_role() in ('team_lead','contractor_admin'),'เฉพาะหัวหน้าทีมหรือผู้ดูแลบริษัท');
  perform need(j.status<>'stopped','งานนี้ถูกสั่งหยุด รอ SCG ปลดล็อก');
  perform need(j.status not in ('done','cancelled'),'งานนี้ปิดแล้ว');
  perform need(d between j.start_date and j.end_date,'วันนี้ไม่อยู่ในช่วงวันทำงานของงานนี้');
  select * into pm from permits where job_id=p_job;
  perform need(pm.status='approved','ใบอนุญาตยังไม่ได้รับอนุมัติ');
  bl := contractor_blockers(j.contractor_id,j.scg_company_id); perform need(cardinality(bl)=0,array_to_string(bl,' · '));
  perform need(not exists(select 1 from checkins where job_id=p_job and work_date=d and not voided),'งานนี้ check-in วันนี้แล้ว');
  -- ปิดงานวันก่อน
  select * into prevci from checkins c where c.job_id=p_job and c.work_date<d and not c.voided order by work_date desc limit 1;
  if found then perform need(exists(select 1 from closeouts where checkin_id=prevci.id),'ยังไม่ได้ปิดงานของวันที่ '||to_char(prevci.work_date,'DD/MM')); end if;
  -- ไม่มี finding วิกฤต/LSR ค้าง หรือ finding เกินกำหนด
  perform need(not exists(select 1 from findings where job_id=p_job and status='open' and (severity in ('lsr','critical') or due_at<now())),'มีข้อบกพร่องค้างเกินกำหนด แก้ในเมนู "ต้องแก้" ก่อน');
  select * into p from projects where id=j.project_id;

  -- ช่าง
  perform need(jsonb_array_length(coalesce(p_payload->'worker_ids','[]'))>0,'เลือกช่างอย่างน้อย 1 คน');
  perform need(coalesce(p_payload#>>'{photos,team}','')<>'' and coalesce(p_payload#>>'{photos,site}','')<>'','ต้องมีรูปทีมรวมและรูปจุดทำงาน');
  wah := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p_payload->'wah_worker_ids') x),'{}');
  wahs := 'wah'=any(j.hazards) and coalesce(p_payload->>'weather_choice','')<>'ground_only';
  for w in select x::uuid from jsonb_array_elements_text(p_payload->'worker_ids') x loop
    perform need(exists(select 1 from workers where id=w and contractor_id=j.contractor_id),'มีช่างที่ไม่ใช่ของบริษัทนี้');
    bl := worker_blockers(w,j.scg_company_id,j.hazards,d,wahs and w=any(wah));
    perform need(cardinality(bl)=0,(select full_name from workers where id=w)||': '||array_to_string(bl,', '));
  end loop;
  if wahs then
    perform need(wah <@ coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p_payload->'worker_ids') x),'{}'),'คนขึ้นที่สูงต้องอยู่ในรายชื่อช่างวันนี้');
    perform need(cardinality(wah)>=2,'งานบนที่สูงต้องมีอย่างน้อย 2 คน (Buddy)');
    -- ตรวจสุขภาพประจำวัน
    foreach w in array wah loop
      select h into hr from jsonb_array_elements(coalesce(p_payload->'health','[]')) h where (h->>'worker_id')::uuid=w order by coalesce((h->>'retest')::boolean,false) desc limit 1;
      perform need(hr is not null,'ยังไม่ตรวจสุขภาพ: '||(select full_name from workers where id=w));
      hpass := (hr->>'pulse')::int between 60 and 100 and (hr->>'sys')::int between 90 and 140 and (hr->>'dia')::int between 60 and 90 and coalesce((hr->>'alcohol')::numeric,1)=0;
      perform need(hpass,(select full_name from workers where id=w)||': ผลตรวจสุขภาพไม่ผ่าน ขึ้นที่สูงวันนี้ไม่ได้ (ทำงานที่พื้นได้)');
      perform need(coalesce(hr->>'photo','')<>'','ต้องมีรูปหน้าจอเครื่องวัด: '||(select full_name from workers where id=w));
    end loop;
  else
    wah := '{}';
  end if;

  -- สภาพอากาศ
  wlv := coalesce(p_payload#>>'{weather,level}','ok');
  if 'wah'=any(j.hazards) and wlv in ('warn','stop') then
    perform need(coalesce(p_payload->>'weather_choice','') in ('ack','ground_only'),'ยืนยันการจัดการสภาพอากาศ');
    if wlv='stop' then perform need(p_payload->>'weather_choice'='ground_only','อากาศระดับหยุดงานบนที่สูง: เลือก "ทำเฉพาะงานที่พื้น" หรือเลื่อนงาน'); end if;
  end if;

  -- เช็กลิสต์: ทุกข้อในหมวดที่เกี่ยวข้องต้องตอบ · ข้อวิกฤตไม่ผ่านต้องแก้แล้วมีรูป
  secs := job_sections(j);
  if not wahs then secs := array_remove(array_remove(array_remove(secs,'wah'),'ladder'),'scaffold'); end if;
  for it in select * from checklist_items(j.scg_company_id) c where c.sec=any(secs) loop
    a := p_payload->'answers'->it.code;
    if it.setup and wahs then continue; end if;  -- ข้อที่ส่งรูปในขั้นบัตรส้ม
    perform need(a is not null and a->>'v' in ('pass','fail','na'),'ยังตอบไม่ครบ: '||it.code);
    if a->>'v'='fail' then
      perform need(coalesce(a->>'photo','')<>'','ข้อไม่ผ่านต้องมีรูป: '||it.code);
      if it.crit then perform need(coalesce(a->>'fixed_photo','')<>'','ข้อวิกฤต '||it.code||' ต้องแก้ไขและถ่ายรูปหลังแก้ก่อนเริ่มงาน'); end if;
    end if;
  end loop;
  perform need(coalesce((p_payload->>'rules_ack')::boolean,false),'ทีมต้องรับทราบกฎระหว่างทำงาน');

  -- ตำแหน่ง
  rad := sett_int(j.scg_company_id,'rules','radius_m',200);
  if j.lat is not null and (p_payload->>'lat') is not null then
    dist := distance_m(j.lat,j.lng,(p_payload->>'lat')::float8,(p_payload->>'lng')::float8);
    if dist>rad then perform need(coalesce(trim(p_payload->>'out_of_radius_reason'),'')<>'','อยู่นอกรัศมี '||rad||' ม. ต้องใส่เหตุผล'); end if;
  elsif j.lat is null and (p_payload->>'lat') is not null then
    update jobs set lat=(p_payload->>'lat')::float8, lng=(p_payload->>'lng')::float8 where id=p_job;
  end if;

  late := bkk_now()::time > j.start_time + make_interval(mins=>sett_int(j.scg_company_id,'rules','late_min',30));
  -- บัตรผ่าน 2 ขั้น: งานที่สูงที่ต้องติดจุดยึด/ทางเดิน → บัตรส้มก่อน
  if wahs and exists(select 1 from checklist_items(j.scg_company_id) c where c.setup and c.sec=any(secs)) then
    stg := 'setup';
    lim := sett_int(j.scg_company_id,'rules','setup_minutes',60);
    setup_due := now()+make_interval(mins=>lim);
    setup_w := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p_payload->'setup_worker_ids') x),j.setup_worker_ids);
    if cardinality(setup_w)=0 then setup_w := wah[1:2]; end if;
    perform need(setup_w <@ wah,'คนขึ้นติดตั้งจุดยึดต้องผ่านตรวจสุขภาพและอยู่ในรายชื่อคนขึ้นที่สูง');
  end if;

  insert into checkins(job_id,work_date,team_id,lead_id,worker_ids,wah_worker_ids,lat,lng,distance_m,out_of_radius_reason,answers,photos,toolbox_topic,rules_ack,
    weather,weather_choice,late,stage,setup_worker_ids,setup_due)
  values(p_job,d,j.team_id,auth.uid(),(select array_agg(x::uuid) from jsonb_array_elements_text(p_payload->'worker_ids') x),wah,
    (p_payload->>'lat')::float8,(p_payload->>'lng')::float8,dist,nullif(p_payload->>'out_of_radius_reason',''),coalesce(p_payload->'answers','{}'),p_payload->'photos',
    p_payload->>'toolbox_topic',true,p_payload->'weather',p_payload->>'weather_choice',late,stg,setup_w,setup_due)
  returning id,pass_token into ci,tok;

  insert into health_checks(checkin_id,worker_id,work_date,pulse,sys,dia,alcohol,photo_path,retest,pass)
  select ci,(h->>'worker_id')::uuid,d,(h->>'pulse')::int,(h->>'sys')::int,(h->>'dia')::int,(h->>'alcohol')::numeric,h->>'photo',coalesce((h->>'retest')::boolean,false),
    (h->>'pulse')::int between 60 and 100 and (h->>'sys')::int between 90 and 140 and (h->>'dia')::int between 60 and 90 and coalesce((h->>'alcohol')::numeric,1)=0
  from jsonb_array_elements(coalesce(p_payload->'health','[]')) h where (h->>'worker_id') is not null;

  update jobs set status='in_progress' where id=p_job;

  -- ข้อไม่ผ่าน → finding
  for it in select * from checklist_items(j.scg_company_id) c where c.sec=any(secs) loop
    a := p_payload->'answers'->it.code;
    if a is not null and a->>'v'='fail' then
      nf := nf+1;
      sev := case when it.crit then 'critical' else 'normal' end;
      due := now()+make_interval(hours=>sett_int(j.scg_company_id,'sla','finding_hours',48));
      insert into findings(scg_company_id,job_id,checkin_id,source,item_code,item_text,severity,photo_path,due_at,status,fix_photo_path,fix_note,fixed_at,created_by)
      values(j.scg_company_id,p_job,ci,'checkin',it.code,it.txt,sev,a->>'photo',due,case when it.crit then 'fixed' else 'open' end,
        case when it.crit then a->>'fixed_photo' end,case when it.crit then 'แก้ไขก่อนเริ่มงาน' end,case when it.crit then now() end,auth.uid());
    end if;
  end loop;
  if nf>0 then
    perform notify_many(contractor_admins(j.contractor_id),j.scg_company_id,'finding','ข้อบกพร่องจาก check-in '||j.po_no,nf||' ข้อ','jobs',p_job,false,true);
    perform notify_many(project_ics(j.project_id),j.scg_company_id,'finding','check-in พบข้อบกพร่อง '||nf||' ข้อ · '||j.po_no,'ตรวจรับการแก้ไขในกล่องงาน','jobs',p_job,false,false);
  end if;
  if p_payload->>'weather_choice'='ground_only' then
    perform notify_many(project_ics(j.project_id),j.scg_company_id,'weather','สภาพอากาศ: '||j.po_no||' ทำเฉพาะงานที่พื้นวันนี้',p_payload#>>'{weather,text}','jobs',p_job,false,false);
  end if;
  perform audit(j.scg_company_id,'checkin','checkins',ci,jsonb_build_object('late',late,'findings',nf,'stage',stg));
  return jsonb_build_object('token',tok,'checkin_id',ci,'findings',nf,'late',late,'stage',stg,'setup_due',setup_due);
end $$;

-- ส่งรูปจุดยึด/ทางเดินในขั้นบัตรส้ม → บัตรเขียว
create or replace function submit_setup(p_checkin uuid, p_photos jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare c checkins; j jobs; it record; secs text[];
begin
  select * into c from checkins where id=p_checkin; perform need(found,'ไม่พบ check-in');
  select * into j from jobs where id=c.job_id;
  perform need(j.contractor_id=my_contractor(),'ไม่ใช่งานของบริษัทคุณ');
  perform need(not c.voided,'บัตรผ่านนี้ถูกยกเลิกแล้ว');
  perform need(c.stage='setup','บัตรนี้อยู่ขั้นทำงานแล้ว');
  secs := job_sections(j);
  for it in select * from checklist_items(j.scg_company_id) x where x.setup and x.sec=any(secs) loop
    perform need(coalesce(p_photos->>it.code,'')<>'','ต้องส่งรูป: '||it.txt);
  end loop;
  update checkins set stage='work', setup_photos=p_photos, setup_done_at=now() where id=p_checkin;
  if c.setup_due<now() then
    perform notify_many(project_ics(j.project_id),j.scg_company_id,'setup','ส่งรูปจุดยึดช้ากว่ากำหนด · '||j.po_no,'ส่งเมื่อ '||to_char(bkk_now(),'HH24:MI'),'checkins',p_checkin,false,false);
  end if;
  perform audit(j.scg_company_id,'setup_done','checkins',p_checkin,null);
  return jsonb_build_object('stage','work','late',c.setup_due<now());
end $$;

create or replace function submit_closeout(p_checkin uuid, p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare c checkins; j jobs; it jsonb; n int;
begin
  select * into c from checkins where id=p_checkin; perform need(found,'ไม่พบ check-in');
  select * into j from jobs where id=c.job_id;
  perform need(j.contractor_id=my_contractor(),'ไม่ใช่งานของบริษัทคุณ');
  perform need(not exists(select 1 from closeouts where checkin_id=p_checkin),'ปิดงานวันนี้แล้ว');
  for it in select * from jsonb_array_elements(coalesce(setting(j.scg_company_id,'closeout'),'[]')) loop
    perform need(p_payload->'answers'->(it->>'code') is not null,'ยังตอบไม่ครบ: '||(it->>'code'));
  end loop;
  select count(*) into n from jsonb_array_elements_text(coalesce(p_payload#>'{photos,after}','[]')) x where x<>'';
  perform need(n>=2,'ต้องมีรูปหลังเลิกงาน 2 รูป');
  if coalesce((p_payload->>'damage')::boolean,false) then perform need(coalesce(trim(p_payload->>'damage_note'),'')<>'','อธิบายความเสียหาย'); end if;
  insert into closeouts(checkin_id,job_id,answers,photos,damage,damage_note,incident,final,created_by)
  values(p_checkin,j.id,p_payload->'answers',p_payload->'photos',coalesce((p_payload->>'damage')::boolean,false),p_payload->>'damage_note',
    coalesce((p_payload->>'incident')::boolean,false),coalesce((p_payload->>'final')::boolean,false),auth.uid());
  if coalesce((p_payload->>'final')::boolean,false) then update jobs set status='done' where id=j.id; end if;
  if coalesce((p_payload->>'damage')::boolean,false) then
    perform notify_many(project_ics(j.project_id)||co_users(j.scg_company_id,array['safety_admin']),j.scg_company_id,'damage','แจ้งความเสียหาย '||j.po_no,p_payload->>'damage_note','jobs',j.id,true,true);
  end if;
  perform audit(j.scg_company_id,'closeout','checkins',p_checkin,jsonb_build_object('final',p_payload->'final'));
  return jsonb_build_object('incident',coalesce((p_payload->>'incident')::boolean,false));
end $$;

-- ---------- แจ้งเหตุ / SOS ----------
create or replace function report_incident(p_co uuid, p_job uuid, p_kind text, p_desc text, p_photos text[], p_lat float8, p_lng float8, p_level text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare j jobs; co uuid := p_co; ctr uuid := my_contractor(); iid uuid; urgent boolean; ttl text; who uuid[];
begin
  perform need(p_kind in ('sos','injury','property','near_miss','unsafe_condition','unsafe_act'),'เลือกประเภทเหตุการณ์');
  if p_job is not null then
    select * into j from jobs where id=p_job; perform need(found and can_see_job(p_job),'ไม่พบงาน');
    co := j.scg_company_id; ctr := j.contractor_id;
  end if;
  perform need(co is not null and co=any(my_cos()),'เลือกบริษัท SCG');
  perform need(p_kind='sos' or coalesce(trim(p_desc),'')<>'' or cardinality(coalesce(p_photos,'{}'))>0,'ใส่ข้อความหรือรูปอย่างน้อย 1 อย่าง');
  insert into incidents(scg_company_id,job_id,contractor_id,kind,level,description,photos,lat,lng,reported_by)
  values(co,p_job,ctr,p_kind,p_level,p_desc,coalesce(p_photos,'{}'),p_lat,p_lng,auth.uid()) returning id into iid;
  urgent := p_kind in ('sos','injury');
  ttl := case p_kind when 'sos' then 'SOS ฉุกเฉิน' when 'injury' then 'อุบัติเหตุมีผู้บาดเจ็บ' when 'property' then 'อุบัติเหตุทรัพย์สินเสียหาย'
    when 'near_miss' then 'Near miss' when 'unsafe_condition' then 'สภาพไม่ปลอดภัย' else 'พฤติกรรมไม่ปลอดภัย' end;
  who := co_users(co,array['safety_admin'])||case when p_job is not null then project_ics(j.project_id) else '{}' end
    ||case when ctr is not null and urgent then contractor_admins(ctr) else '{}' end
    ||case when urgent then co_users(co,array['ic_qc_manager']) else '{}' end;
  perform notify_many(who,co,'incident',ttl||coalesce(' · '||j.po_no||' บ้าน '||coalesce(j.house_no,''),''),
    coalesce(p_desc,'')||case when p_lat is not null then ' · พิกัด https://maps.google.com/?q='||p_lat||','||p_lng else '' end,'incidents',iid,urgent,true);
  perform audit(co,'incident','incidents',iid,jsonb_build_object('kind',p_kind));
  return iid;
end $$;

-- SOS: แจ้งด่วน + คืนเบอร์ติดต่อ
create or replace function sos(p_job uuid, p_lat float8, p_lng float8, p_co uuid default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare iid uuid; j jobs; p projects; co uuid := p_co;
begin
  if p_job is not null then select * into j from jobs where id=p_job; co := j.scg_company_id; select * into p from projects where id=j.project_id; end if;
  if co is null then co := (my_cos())[1]; end if;
  iid := report_incident(co,p_job,'sos','กด SOS จากหน้างาน',null,p_lat,p_lng);
  return jsonb_build_object('incident',iid,'hospital',p.hospital,'hospital_phone',p.hospital_phone,
    'ic_name',(select coalesce(full_name,email) from profiles where id=p.ic_id),'ic_phone',(select phone from profiles where id=p.ic_id));
end $$;

create or replace function handle_incident(p_id uuid, p_status text, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare i incidents;
begin
  select * into i from incidents where id=p_id;
  perform need(found and has_co(i.scg_company_id),'ไม่มีสิทธิ์');
  perform need(p_status in ('acknowledged','closed'),'สถานะไม่ถูกต้อง');
  update incidents set status=p_status, handled_by=auth.uid(), handled_at=now(), handle_note=p_note where id=p_id;
  update notifications set ack_at=now() where ref_table='incidents' and ref_id=p_id and to_id=auth.uid() and ack_at is null;
  perform audit(i.scg_company_id,'incident_'||p_status,'incidents',p_id,jsonb_build_object('note',p_note));
end $$;

-- ---------- Findings ----------
create or replace function fix_finding(p_finding uuid, p_photo text, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare f findings; j jobs;
begin
  select * into f from findings where id=p_finding; select * into j from jobs where id=f.job_id;
  perform need(j.contractor_id=my_contractor(),'ไม่ใช่งานของบริษัทคุณ');
  perform need(f.status='open','รายการนี้แจ้งแก้แล้ว');
  perform need(p_photo is not null,'ต้องแนบรูปหลังแก้');
  update findings set status='fixed', fix_photo_path=p_photo, fix_note=p_note, fixed_at=now() where id=p_finding;
  perform notify_many(project_ics(j.project_id),j.scg_company_id,'finding','แจ้งแก้แล้ว รอตรวจรับ: '||f.item_text,j.po_no,'findings',p_finding,false,true);
  update notifications set ack_at=now() where ref_table='jobs' and ref_id=j.id and kind='finding' and to_id=auth.uid() and ack_at is null;
end $$;

create or replace function verify_finding(p_finding uuid, p_ok boolean, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare f findings; j jobs;
begin
  select * into f from findings where id=p_finding; select * into j from jobs where id=f.job_id;
  perform need(has_co(j.scg_company_id) and my_role() in ('installation_consultant','ic_qc_manager','safety_admin'),'ไม่มีสิทธิ์ตรวจรับ');
  perform need(f.status='fixed','ยังไม่มีการแจ้งแก้');
  if p_ok then update findings set status='verified', verified_by=auth.uid(), verified_at=now() where id=p_finding;
  else
    perform need(coalesce(trim(p_note),'')<>'','ใส่เหตุผลที่ไม่ผ่าน');
    update findings set status='open', fix_note='ตีกลับ: '||p_note, due_at=greatest(due_at,now()+interval '24 hours') where id=p_finding;
    perform notify_many(contractor_admins(j.contractor_id),j.scg_company_id,'finding','การแก้ไขไม่ผ่าน: '||f.item_text,p_note,'findings',p_finding,false,true);
  end if;
  update notifications set ack_at=now() where ref_table='findings' and ref_id=p_finding and to_id=auth.uid() and ack_at is null;
  perform audit(j.scg_company_id,'verify_finding','findings',p_finding,jsonb_build_object('ok',p_ok));
end $$;

-- ---------- สั่งหยุด / ปลดล็อก ----------
create or replace function stop_job(p_job uuid, p_reason text, p_lsr_rule int, p_photo text) returns void language plpgsql security definer set search_path=public as $$
declare j jobs;
begin
  select * into j from jobs where id=p_job;
  perform need(has_co(j.scg_company_id) and my_role() in ('installation_consultant','ic_qc_manager','safety_admin','ms_manager','ms_director'),'ไม่มีสิทธิ์สั่งหยุดงาน');
  perform need(coalesce(trim(p_reason),'')<>'','ระบุสิ่งที่พบ');
  update jobs set status='stopped', stop_reason=case when p_lsr_rule is not null then 'LSR ข้อ '||p_lsr_rule||': ' else '' end||p_reason where id=p_job;
  update checkins set voided=true, void_reason='สั่งหยุดงาน' where job_id=p_job and work_date=bkk_today() and not voided
    and not exists(select 1 from closeouts x where x.checkin_id=checkins.id);
  insert into findings(scg_company_id,job_id,source,item_text,severity,photo_path,status,created_by,due_at)
  values(j.scg_company_id,p_job,'stop',p_reason,case when p_lsr_rule is not null then 'lsr' else 'critical' end,p_photo,'open',auth.uid(),now());
  perform notify_many(contractor_admins(j.contractor_id)||job_lead(p_job)||project_ics(j.project_id)||co_users(j.scg_company_id,array['safety_admin']),
    j.scg_company_id,'stop','สั่งหยุดงาน '||j.po_no||case when p_lsr_rule is not null then ' (LSR ข้อ '||p_lsr_rule||')' else '' end,p_reason,'jobs',p_job,true,true);
  perform audit(j.scg_company_id,'stop_job','jobs',p_job,jsonb_build_object('reason',p_reason,'lsr',p_lsr_rule));
end $$;

create or replace function resume_job(p_job uuid, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare j jobs;
begin
  select * into j from jobs where id=p_job;
  perform need(has_co(j.scg_company_id) and my_role() in ('installation_consultant','ic_qc_manager','safety_admin','ms_manager'),'ไม่มีสิทธิ์ปลดล็อก');
  perform need(j.status='stopped','งานนี้ไม่ได้ถูกหยุด');
  update jobs set status='approved', stop_reason=null where id=p_job;
  update findings set status='verified', verified_by=auth.uid(), verified_at=now(), fix_note=coalesce(fix_note,p_note) where job_id=p_job and source='stop' and status<>'verified';
  perform notify_many(contractor_admins(j.contractor_id)||job_lead(p_job),j.scg_company_id,'resume','ปลดล็อกงาน '||j.po_no||' · check-in ใหม่ได้',p_note,'jobs',p_job,false,false);
  perform audit(j.scg_company_id,'resume_job','jobs',p_job,jsonb_build_object('note',p_note));
end $$;

-- ---------- แจ้งเตือน ----------
create or replace function ack(p_id uuid) returns void language sql security definer set search_path=public as
$$ update notifications set ack_at=now() where id=p_id and to_id=auth.uid() and ack_at is null $$;
create or replace function ack_all_info() returns void language sql security definer set search_path=public as
$$ update notifications set ack_at=now() where to_id=auth.uid() and not need_ack and ack_at is null $$;

-- ---------- ตรวจบัตรผ่าน (สแกน QR) ----------
create or replace function verify_pass(p_token text) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare c checkins; j jobs; closed boolean; valid boolean; base jsonb;
begin
  select * into c from checkins where pass_token=p_token;
  if not found then return jsonb_build_object('valid',false,'found',false); end if;
  select * into j from jobs where id=c.job_id;
  closed := exists(select 1 from closeouts where checkin_id=c.id);
  valid := not c.voided and not closed and c.work_date=bkk_today() and j.status<>'stopped';
  base := jsonb_build_object('valid',valid,'found',true,'stage',c.stage,'closed',closed,'voided',c.voided,'stopped',j.status='stopped',
    'work_date',c.work_date,'company_color',(select color from scg_companies where id=j.scg_company_id),'company',(select name from scg_companies where id=j.scg_company_id));
  if not coalesce(has_co(j.scg_company_id) or j.contractor_id=my_contractor(),false) then return base; end if;
  return base||jsonb_build_object('job_id',j.id,'po_no',j.po_no,'house_no',j.house_no,'project',(select name from projects where id=j.project_id),
    'contractor',(select name from contractors where id=j.contractor_id),'time',to_char(c.created_at at time zone 'Asia/Bangkok','HH24:MI'),
    'setup_due',c.setup_due,'hazards',j.hazards,'checkin_id',c.id,
    'workers',(select jsonb_agg(jsonb_build_object('name',w.full_name,'wah',w.id=any(c.wah_worker_ids),'setup',w.id=any(c.setup_worker_ids)) order by w.full_name) from workers w where w.id=any(c.worker_ids)));
end $$;
grant execute on function verify_pass(text) to anon;
-- =====================================================================
-- 8) งานอัตโนมัติ (เรียกจาก Google Apps Script ด้วย service key)
-- =====================================================================

-- งานที่เกี่ยวกับการแจ้งเตือน (ใช้หาผู้รับต่อ)
create or replace function ref_job(tbl text, rid uuid) returns uuid language sql stable security definer set search_path=public as $$
  select case tbl when 'jobs' then rid
    when 'findings' then (select job_id from findings where id=rid)
    when 'checkins' then (select job_id from checkins where id=rid)
    when 'incidents' then (select job_id from incidents where id=rid)
    when 'permits' then (select job_id from permits where id=rid) end $$;

-- ส่งต่อเมื่อไม่รับทราบ
-- ทั่วไป: หัวหน้าทีม → ผู้ดูแลบริษัท → IC → IC & QC Mgr · ด่วน: หัวหน้าทีม → ผู้ดูแลบริษัท → IC + Safety → M&S Mgr
-- ฝั่ง SCG: IC → IC สำรอง → IC & QC Mgr → M&S Mgr
create or replace function run_escalations() returns jsonb language plpgsql security definer set search_path=public as $$
declare n notifications; u profiles; jid uuid; j jobs; nxt uuid[]; cnt int := 0; rep int := 0;
begin
  for n in select * from notifications where need_ack and ack_at is null and not escalated and escalate_at<now() for update skip locked loop
    select * into u from profiles where id=n.to_id;
    jid := ref_job(n.ref_table,n.ref_id); j := null;
    if jid is not null then select * into j from jobs where id=jid; end if;
    nxt := case u.role
      when 'team_lead' then contractor_admins(u.contractor_id)
      when 'contractor_admin' then case when j.id is not null then project_ics(j.project_id)||case when n.urgent then co_users(j.scg_company_id,array['safety_admin']) else '{}' end else '{}' end
      when 'installation_consultant' then case when j.id is not null then
          array_remove(array[(select case when p.ic_id=u.id then p.backup_ic_id end from projects p where p.id=j.project_id)],null)||co_users(j.scg_company_id,array['ic_qc_manager'])
        else co_users(n.scg_company_id,array['ic_qc_manager']) end
      when 'ic_qc_manager' then co_users(coalesce(j.scg_company_id,n.scg_company_id),array['ms_manager'])
      when 'safety_admin' then case when n.urgent then co_users(coalesce(j.scg_company_id,n.scg_company_id),array['ms_manager']) else '{}' end
      else '{}' end;
    update notifications set escalated=true where id=n.id;
    nxt := array(select distinct x from unnest(nxt) x where x is not null and x<>n.to_id);
    if cardinality(nxt)>0 then
      insert into notifications(to_id,scg_company_id,kind,title,body,ref_table,ref_id,urgent,need_ack,escalate_at,repeat_at)
      select x,n.scg_company_id,n.kind,'ส่งต่อ (ยังไม่มีผู้รับทราบ): '||n.title,
        coalesce(n.body||' · ','')||'ผู้รับเดิม '||coalesce(u.full_name,u.email),n.ref_table,n.ref_id,n.urgent,true,
        now()+case when n.urgent then make_interval(mins=>sett_int(n.scg_company_id,'sla','ack_urgent_min',30)) else make_interval(mins=>sett_int(n.scg_company_id,'sla','ack_normal_min',240)) end,
        case when n.urgent then now()+interval '5 minutes' end
      from unnest(nxt) x;
      cnt := cnt+cardinality(nxt);
    end if;
  end loop;
  -- เรื่องด่วนที่ยังไม่รับทราบ: ส่งซ้ำทุก 5 นาที
  update notifications set sent_line_at=null, sent_push_at=null, repeat_at=now()+interval '5 minutes'
   where urgent and need_ack and ack_at is null and repeat_at<now() and created_at>now()-interval '6 hours';
  get diagnostics rep = row_count;
  -- บัตรส้มเกิน 60 นาที → แจ้ง IC ครั้งเดียว
  perform notify_many(project_ics(j2.project_id)||contractor_admins(j2.contractor_id),j2.scg_company_id,'setup',
      'ยังไม่ส่งรูปจุดยึด/ทางเดินเกินเวลา · '||j2.po_no,'บัตรผ่านยังเป็นสีส้ม ห้ามทำงานบนที่สูงนอกจากคนติดตั้ง','checkins',c.id,false,true)
    from checkins c join jobs j2 on j2.id=c.job_id where c.stage='setup' and not c.voided and not c.setup_overdue_sent and c.setup_due<now();
  update checkins set setup_overdue_sent=true where stage='setup' and not voided and not setup_overdue_sent and setup_due<now();
  return jsonb_build_object('escalated',cnt,'repeated',rep);
end $$;

-- งานรายวัน: morning (07:00) · missing_checkin (ทุก 30 นาทีช่วงเช้า) · evening (18:30)
create or replace function run_daily(p_kind text) returns jsonb language plpgsql security definer set search_path=public as $$
declare r record; n int := 0; d date := bkk_today();
begin
  if p_kind='morning' then
    -- แผนงานพรุ่งนี้ที่ยังไม่ยื่น
    for r in select j.*, (select string_agg(po_no,', ') from jobs x where x.contractor_id=j.contractor_id and x.scg_company_id=j.scg_company_id and x.start_date=d+1 and x.status='planned') pos
      from (select distinct on (contractor_id,scg_company_id) * from jobs where start_date=d+1 and status='planned') j loop
      perform notify_many(contractor_admins(r.contractor_id),r.scg_company_id,'plan','ยื่นแผนงานของพรุ่งนี้ก่อน '||coalesce(setting(r.scg_company_id,'sla')->>'permit_deadline','16:00')||' น.',r.pos,'jobs',r.id,false,true);
      n := n+1;
    end loop;
    -- Self-declaration จะหมดอายุใน 30 วัน
    for r in select w.contractor_id, string_agg(w.full_name,', ') names from workers w where w.active and w.selfdec_until between d and d+30
        and not exists(select 1 from notifications x where x.kind='selfdec_due' and x.created_at>now()-interval '7 days' and x.to_id=any(contractor_admins(w.contractor_id)))
      group by w.contractor_id loop
      perform notify_many(contractor_admins(r.contractor_id),null,'selfdec_due','Self-declaration ใกล้ครบปี (ภายใน 30 วัน)',r.names,'contractors',r.contractor_id,false,false);
      n := n+1;
    end loop;
    -- เอกสารบริษัทใกล้หมดอายุ
    for r in select d2.contractor_id, string_agg(d2.doc_type||' '||to_char(d2.expires_on,'DD/MM/YYYY'),', ') docs from contractor_docs d2 where d2.expires_on between d and d+30
        and not exists(select 1 from notifications x where x.kind='doc_due' and x.created_at>now()-interval '7 days' and x.to_id=any(contractor_admins(d2.contractor_id)))
      group by d2.contractor_id loop
      perform notify_many(contractor_admins(r.contractor_id),null,'doc_due','เอกสารบริษัทใกล้หมดอายุ',r.docs,'contractors',r.contractor_id,false,false);
      n := n+1;
    end loop;
  elsif p_kind='missing_checkin' then
    for r in select j.* from jobs j join permits pm on pm.job_id=j.id and pm.status='approved'
      where d between j.start_date and j.end_date and j.status in ('approved','in_progress')
        and bkk_now()::time > j.start_time+make_interval(mins=>sett_int(j.scg_company_id,'rules','late_min',30))
        and not exists(select 1 from checkins c where c.job_id=j.id and c.work_date=d)
        and not exists(select 1 from notifications x where x.kind='missing_checkin' and x.ref_id=j.id and x.created_at::date=d) loop
      perform notify_many(contractor_admins(r.contractor_id)||job_lead(r.id),r.scg_company_id,'missing_checkin','ยังไม่ check-in · '||r.po_no||' บ้าน '||coalesce(r.house_no,''),
        'นัด '||to_char(r.start_time,'HH24:MI')||' น.','jobs',r.id,false,true);
      perform notify_many(project_ics(r.project_id),r.scg_company_id,'missing_checkin','ทีมยังไม่ check-in · '||r.po_no,(select name from contractors where id=r.contractor_id),'jobs',r.id,false,false);
      n := n+1;
    end loop;
  elsif p_kind='evening' then
    for r in select j.*, c.id cid from checkins c join jobs j on j.id=c.job_id where c.work_date=d and not c.voided
        and not exists(select 1 from closeouts x where x.checkin_id=c.id)
        and not exists(select 1 from notifications x where x.kind='missing_closeout' and x.ref_id=j.id and x.created_at::date=d) loop
      perform notify_many(contractor_admins(r.contractor_id)||job_lead(r.id),r.scg_company_id,'missing_closeout','ยังไม่ปิดงานประจำวัน · '||r.po_no,'ปิดงานก่อนเริ่ม check-in พรุ่งนี้','jobs',r.id,false,true);
      n := n+1;
    end loop;
  end if;
  return jsonb_build_object('kind',p_kind,'sent',n);
end $$;

-- สรุปเที่ยงของแต่ละบริษัท SCG
create or replace function today_summary(p_co uuid) returns jsonb language sql stable security definer set search_path=public as $$
  with t as (select j.* from jobs j where j.scg_company_id=p_co and bkk_today() between j.start_date and j.end_date and j.status not in ('cancelled'))
  select jsonb_build_object('company',(select name from scg_companies where id=p_co),'date',bkk_today(),
    'jobs',(select count(*) from t),'high',(select count(*) from t where risk='high'),
    'checked_in',(select count(*) from t where exists(select 1 from checkins c where c.job_id=t.id and c.work_date=bkk_today() and not c.voided)),
    'missing',(select coalesce(jsonb_agg(po_no||' '||coalesce(house_no,'')),'[]') from t join permits pm on pm.job_id=t.id and pm.status='approved'
       where t.status in ('approved','in_progress') and not exists(select 1 from checkins c where c.job_id=t.id and c.work_date=bkk_today())),
    'stopped',(select count(*) from t where status='stopped'),
    'setup_open',(select count(*) from checkins c join t on t.id=c.job_id where c.work_date=bkk_today() and c.stage='setup' and not c.voided),
    'findings_open',(select count(*) from findings f where f.scg_company_id=p_co and f.status='open'),
    'incidents_today',(select count(*) from incidents i where i.scg_company_id=p_co and (i.created_at at time zone 'Asia/Bangkok')::date=bkk_today())) $$;

revoke execute on function run_escalations() from anon, authenticated;
revoke execute on function run_daily(text) from anon, authenticated;
revoke execute on function today_summary(uuid) from anon, authenticated;
revoke execute on function notify(uuid,uuid,text,text,text,text,uuid,boolean,boolean) from anon, authenticated;
revoke execute on function notify_many(uuid[],uuid,text,text,text,text,uuid,boolean,boolean) from anon, authenticated;
revoke execute on function audit(uuid,text,text,uuid,jsonb) from anon, authenticated;

-- =====================================================================
-- 9) ที่เก็บรูป (Supabase Storage)
--    photos/<contractor_id หรือ scg>/... · idcheck/<contractor_id>/... (รูปบัตรชั่วคราว)
-- =====================================================================
insert into storage.buckets(id,name,public) values('photos','photos',false) on conflict (id) do nothing;
insert into storage.buckets(id,name,public) values('idcheck','idcheck',false) on conflict (id) do nothing;
insert into storage.buckets(id,name,public) values('health','health',false) on conflict (id) do nothing;   -- รูปเครื่องวัดสุขภาพ/ใบแพทย์

create or replace function photo_folder_ok(folder text) returns boolean language sql stable as $$
  select auth.uid() is not null and (folder=coalesce(my_contractor()::text,'-') or (is_scg() and folder='scg')) $$;
create or replace function photo_read_ok(folder text) returns boolean language sql stable as $$
  select auth.uid() is not null and (folder=coalesce(my_contractor()::text,'-') or folder='scg' or (is_scg() and folder ~ '^[0-9a-f-]{36}$' and can_see_contractor(folder::uuid))) $$;

drop policy if exists ss_photos_ins on storage.objects;
drop policy if exists ss_photos_read on storage.objects;
drop policy if exists ss_id_ins on storage.objects;
drop policy if exists ss_id_read on storage.objects;
drop policy if exists ss_id_del on storage.objects;
drop policy if exists ss_h_ins on storage.objects;
drop policy if exists ss_h_read on storage.objects;
create policy ss_photos_ins on storage.objects for insert to authenticated with check (bucket_id='photos' and photo_folder_ok((storage.foldername(name))[1]));
create policy ss_photos_read on storage.objects for select to authenticated using (bucket_id='photos' and photo_read_ok((storage.foldername(name))[1]));
create policy ss_id_ins on storage.objects for insert to authenticated with check (bucket_id='idcheck' and (storage.foldername(name))[1]=coalesce(my_contractor()::text,'-'));
create policy ss_id_read on storage.objects for select to authenticated using (bucket_id='idcheck' and is_scg() and photo_read_ok((storage.foldername(name))[1]));
create policy ss_id_del on storage.objects for delete to authenticated using (bucket_id='idcheck' and is_scg() and photo_read_ok((storage.foldername(name))[1]));

create policy ss_h_ins on storage.objects for insert to authenticated with check (bucket_id='health' and (storage.foldername(name))[1]=coalesce(my_contractor()::text,'-'));
create policy ss_h_read on storage.objects for select to authenticated using (bucket_id='health' and (
  ((storage.foldername(name))[1]=coalesce(my_contractor()::text,'-') and my_role()='contractor_admin')
  or (my_role()='safety_admin' and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$' and can_see_contractor(((storage.foldername(name))[1])::uuid))));

-- อัปเดตสด (Realtime)
do $$ begin
  begin alter publication supabase_realtime add table jobs, permits, checkins, closeouts, findings, notifications, worker_links, incidents;
  exception when others then null; end;
end $$;
-- SafeStart v2 · ค่าตั้งต้น (สร้างจาก gen_seed.py) · รันหลัง schema.sql
-- ก่อนรัน: แก้อีเมลผู้ดูแลระบบในบรรทัด invites ด้านล่าง

insert into app_secrets(key,value) values('id_salt',encode(extensions.gen_random_bytes(32),'hex')) on conflict (key) do nothing;
insert into settings(scg_company_id,key,value) values(null,'sla','{"ack_normal_min": 240, "ack_urgent_min": 30, "finding_hours": 48, "permit_deadline": "16:00", "closeout_by": "20:00", "checkin_open": "06:00"}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'rules','{"radius_m": 200, "late_min": 30, "enforce_certs": true, "enforce_docs": false, "setup_minutes": 60, "quiet_from": "21:00", "quiet_to": "06:00"}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'weather','{"gust": [25, 40, 55], "rain_prob": [40, 70], "heat": [27, 33, 42, 52], "work_from": "08:00", "work_to": "17:00"}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'hazard_names','{"wah": "ที่สูง", "electric": "ไฟฟ้า", "hot": "ประกายไฟ", "confined": "ในฝ้า/อับอากาศ", "lifting": "ยกของ", "excavation": "ขุด", "chemical": "สารเคมี"}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'cert_types','{"induction": "อบรมความปลอดภัย SCG (Induction)", "wah": "อบรมทำงานบนที่สูง", "health": "ผลตรวจสุขภาพประจำปี", "confined": "อบรมที่อับอากาศ", "electrician": "ใบรับรองช่างไฟฟ้า", "welder": "ใบรับรองช่างเชื่อม", "scaffold_inspector": "ผู้ตรวจนั่งร้าน", "crane": "ผู้ควบคุมปั้นจั่น/รอก", "other": "อื่น ๆ"}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'hazard_certs','{"all": ["induction"], "wah": ["wah", "health"], "confined": ["confined", "health"]}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'doc_types','{"registration": "หนังสือรับรองบริษัท / ภ.พ.20", "sso": "กองทุนเงินทดแทน / ประกันสังคม", "jp": "ใบรับรอง จป. ตามกฎหมาย", "other": "อื่น ๆ"}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'setup_methods','["ติดจากใต้หลังคา/ในฝ้า", "ติดจากนั่งร้าน หรือบันไดที่ผูกยึดแล้ว", "ใช้ไม้ค้ำคล้องสันจากด้านล่าง", "คล้องโครงสร้างที่ใกล้ที่สุดก่อนขึ้น"]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'checklist','[{"code": "A", "when": "all", "icon": "shield", "title": "ทั่วไป", "items": [{"code": "A1", "text": "ทุกคนพร้อมทำงาน: ไม่ดื่มสุรา ไม่ใช้สารเสพติด ไม่ป่วย", "t": {"my": "အားလုံး အလုပ်လုပ်ရန် အသင့်ဖြစ်သည်: အရက်မသောက်၊ မူးယစ်ဆေးမသုံး၊ မဖျားနာ", "km": "អ្នករាល់គ្នាត្រៀមខ្លួនធ្វើការ: មិនផឹកស្រា មិនប្រើគ្រឿងញៀន មិនឈឺ", "lo": "ທຸກຄົນພ້ອມເຮັດວຽກ: ບໍ່ດື່ມເຫຼົ້າ ບໍ່ໃຊ້ຢາເສບຕິດ ບໍ່ເຈັບປ່ວຍ"}, "crit": true, "lsr": 6, "ill": "fit"}, {"code": "A2", "text": "PPE ครบ: หมวกมีสายรัดคาง รองเท้านิรภัย ถุงมือ แว่นตามงาน", "t": {"my": "PPE ပြည့်စုံ: မေးသိုင်းကြိုးပါ ဦးထုပ်၊ ဘေးကင်းဖိနပ်၊ လက်အိတ်၊ မျက်မှန်", "km": "PPE គ្រប់: មួកមានខ្សែចងចង្កា ស្បែកជើងសុវត្ថិភាព ស្រោមដៃ វ៉ែនតា", "lo": "PPE ຄົບ: ໝວກມີສາຍຮັດຄາງ ເກີບນິລະໄພ ຖົງມື ແວ່ນຕາ"}, "crit": false, "ill": "ppe"}, {"code": "A3", "text": "ประชุม Toolbox และทุกคนรู้ขั้นตอนงาน (JSA) ของวันนี้", "t": {"my": "Toolbox အစည်းအဝေးလုပ်ပြီး ယနေ့ အလုပ်အဆင့်များ (JSA) ကို အားလုံးသိသည်", "km": "ប្រជុំ Toolbox ហើយអ្នករាល់គ្នាដឹងពីជំហានការងារ (JSA) ថ្ងៃនេះ", "lo": "ປະຊຸມ Toolbox ແລະ ທຸກຄົນຮູ້ຂັ້ນຕອນວຽກ (JSA) ມື້ນີ້"}, "crit": false, "ill": "toolbox"}, {"code": "A4", "text": "เครื่องมือไฟฟ้าสภาพดี มีการ์ด สายไม่ชำรุด", "t": {"my": "လျှပ်စစ်ကိရိယာ ကောင်းမွန်၊ အကာပါ၊ ကြိုးမပျက်", "km": "ឧបករណ៍អគ្គិសនីល្អ មានរបាំងការពារ ខ្សែមិនខូច", "lo": "ເຄື່ອງມືໄຟຟ້າສະພາບດີ ມີກາດ ສາຍບໍ່ຊຳລຸດ"}, "crit": false, "ill": "tool"}, {"code": "A5", "text": "ปลั๊กพ่วงมีเบรกเกอร์กันไฟดูด (RCD) สายไม่ชำรุด", "t": {"my": "ပလပ်ဆက်ကြိုးတွင် ဓာတ်လိုက်ကာကွယ်ဘရိတ်ကာ (RCD) ပါ၊ ကြိုးမပျက်", "km": "ខ្សែភ្លើងបន្តមានឧបករណ៍ការពារឆក់ (RCD) ខ្សែមិនខូច", "lo": "ປລັກພ່ວງມີເບຣກເກີກັນໄຟດູດ (RCD) ສາຍບໍ່ຊຳລຸດ"}, "crit": true, "ill": "rcd"}, {"code": "A6", "text": "กั้นพื้นที่ + ป้ายเตือนรอบจุดทำงาน", "t": {"my": "အလုပ်နေရာပတ်လည် အကာအရံ + သတိပေးဆိုင်းဘုတ်", "km": "របាំងព័ទ្ធ + ផ្លាកសញ្ញាព្រមានជុំវិញកន្លែងធ្វើការ", "lo": "ກັ້ນພື້ນທີ່ + ປ້າຍເຕືອນອ້ອມຈຸດເຮັດວຽກ"}, "crit": false, "ill": "barricade"}, {"code": "A7", "text": "ชุดปฐมพยาบาล + ถังดับเพลิงพร้อมใช้ที่รถ", "t": {"my": "ရှေးဦးသူနာပြုသေတ္တာ + မီးသတ်ဘူး ကားပေါ်တွင် အသင့်", "km": "ប្រអប់សង្គ្រោះបឋម + បំពង់ពន្លត់អគ្គិភ័យនៅលើឡាន", "lo": "ຊຸດປະຖົມພະຍາບານ + ຖັງດັບເພີງພ້ອມໃຊ້ຢູ່ລົດ"}, "crit": false, "ill": "firstaid"}, {"code": "A8", "text": "จอดรถไม่กีดขวาง หนุนล้อ วัสดุบนรถยึดแน่น", "t": {"my": "ကားကို လမ်းမပိတ်ဘဲ ရပ်၊ ဘီးခံ၊ ကားပေါ်ပစ္စည်း တင်းကျပ်စွာ ချည်", "km": "ចតឡានមិនរារាំង ទ្រកង់ ចងសម្ភារៈលើឡានឱ្យជាប់", "lo": "ຈອດລົດບໍ່ກີດຂວາງ ໜູນລໍ້ ວັດສະດຸເທິງລົດມັດແໜ້ນ"}, "crit": false, "ill": "truck"}, {"code": "A9", "text": "รับทราบเบอร์ฉุกเฉิน 1669 และโรงพยาบาลใกล้สุด", "t": {"my": "အရေးပေါ်ဖုန်း 1669 နှင့် အနီးဆုံးဆေးရုံကို သိသည်", "km": "ដឹងលេខសង្គ្រោះបន្ទាន់ 1669 និងមន្ទីរពេទ្យជិតបំផុត", "lo": "ຮັບຮູ້ເບີສຸກເສີນ 1669 ແລະ ໂຮງໝໍໃກ້ສຸດ"}, "crit": false, "ill": "phone"}, {"code": "A10", "text": "รับทราบคำเตือนสภาพอากาศ/ดัชนีความร้อนวันนี้", "t": {"my": "ယနေ့ ရာသီဥတု/အပူချိန်ညွှန်းကိန်း သတိပေးချက်ကို သိသည်", "km": "ដឹងការព្រមានអាកាសធាតុ/សន្ទស្សន៍កម្តៅថ្ងៃនេះ", "lo": "ຮັບຮູ້ຄຳເຕືອນສະພາບອາກາດ/ດັດຊະນີຄວາມຮ້ອນມື້ນີ້"}, "crit": false, "ill": "weather"}], "rules": []}, {"code": "H", "when": "wah", "icon": "height", "title": "ที่สูง / หลังคา", "items": [{"code": "H3", "text": "จุดยึด/Lifeline ติดตั้งแล้วและแข็งแรง", "t": {"my": "ချိတ်ဆွဲရန်နေရာ/Lifeline တပ်ဆင်ပြီး ခိုင်ခံ့သည်", "km": "ចំណុចចង/Lifeline បានដំឡើងហើយ និងរឹងមាំ", "lo": "ຈຸດຍຶດ/Lifeline ຕິດຕັ້ງແລ້ວ ແລະ ແຂງແຮງ"}, "crit": true, "lsr": 1, "ill": "anchor", "setup": true}, {"code": "H4", "text": "เลือกระบบกันตกเหมาะกับหน้างาน: ลาด <20° ใช้ Lifeline แนวนอน · >20° ใช้ Work positioning · สูง <4 ม. ใช้ Restraint/SRL", "t": {"my": "နေရာနှင့်ကိုက်ညီသော ပြုတ်ကျကာကွယ်စနစ်: ဆင်ခြေလျှော <20° အလျားလိုက် Lifeline · >20° Work positioning · <4 မီတာ Restraint/SRL", "km": "ជ្រើសប្រព័ន្ធការពារការធ្លាក់ឱ្យសម: ជម្រាល <20° Lifeline ផ្តេក · >20° Work positioning · ខ្ពស់ <4ម Restraint/SRL", "lo": "ເລືອກລະບົບກັນຕົກໃຫ້ເໝາະ: ຄ້ອຍ <20° Lifeline ແນວນອນ · >20° Work positioning · ສູງ <4 ມ. Restraint/SRL"}, "crit": false, "na": true, "ill": "system"}, {"code": "H5", "text": "Harness + Double lanyard ตรวจก่อนใช้ ไม่ชำรุด", "t": {"my": "Harness + Double lanyard ကို အသုံးမပြုမီ စစ်ဆေး၊ မပျက်စီး", "km": "Harness + Double lanyard ពិនិត្យមុនប្រើ មិនខូច", "lo": "Harness + Double lanyard ກວດກ່ອນໃຊ້ ບໍ່ຊຳລຸດ"}, "crit": true, "lsr": 1, "ill": "harness"}, {"code": "H6", "text": "ทางเดินบนหลังคาเสร็จ จุดเปราะบาง (แผ่นโปร่งแสง ฝ้า กระเบื้องผุ) ปิด/กั้นแล้ว", "t": {"my": "အမိုးပေါ်လမ်းလျှောက်ပြီး၊ ကျိုးလွယ်နေရာ (အလင်းပေါက်ပြား၊ မျက်နှာကျက်) ပိတ်/ကာပြီး", "km": "ផ្លូវដើរលើដំបូលរួចរាល់ ចំណុចផុយ (សន្លឹកថ្លា ពិដាន ក្បឿងពុក) បានបិទ/រាំង", "lo": "ທາງຍ່າງເທິງຫຼັງຄາແລ້ວ ຈຸດເປາະບາງ (ແຜ່ນໂປ່ງແສງ ຝ້າ ກະເບື້ອງເປື່ອຍ) ປິດ/ກັ້ນແລ້ວ"}, "crit": true, "ill": "walkway", "setup": true}, {"code": "H7", "text": "บนหลังคาอย่างน้อย 2 คน (Buddy) + ชุดกู้ภัยพร้อม นำลงพื้นได้ใน 6 นาที", "t": {"my": "အမိုးပေါ်တွင် အနည်းဆုံး ၂ ယောက် (Buddy) + ကယ်ဆယ်ရေးပစ္စည်း၊ ၆ မိနစ်အတွင်း မြေပြင်သို့ချနိုင်", "km": "នៅលើដំបូលយ៉ាងហោចណាស់ ២នាក់ (Buddy) + ឧបករណ៍សង្គ្រោះ នាំចុះដីក្នុង ៦នាទី", "lo": "ເທິງຫຼັງຄາຢ່າງໜ້ອຍ 2 ຄົນ (Buddy) + ຊຸດກູ້ໄພພ້ອມ ນຳລົງພື້ນໄດ້ໃນ 6 ນາທີ"}, "crit": true, "ill": "buddy"}, {"code": "H8", "text": "ขอบหลังคา/ช่องเปิดมีราวกันตกหรือเส้นเตือน", "t": {"my": "အမိုးအစွန်း/အပေါက်တွင် လက်ရန်း သို့မဟုတ် သတိပေးကြိုး", "km": "គែមដំបូល/រន្ធមានរបាំងការពារ ឬខ្សែព្រមាន", "lo": "ຂອບຫຼັງຄາ/ຊ່ອງເປີດມີຮາວກັນຕົກ ຫຼື ເສັ້ນເຕືອນ"}, "crit": false, "na": true, "ill": "edge"}, {"code": "H9", "text": "เครื่องมือมีสายคล้อง ยกวัสดุด้วยรอก/เชือก ห้ามโยน", "t": {"my": "ကိရိယာများကို ကြိုးချိတ်၊ ပစ္စည်းကို ကြိုး/ဘီးဖြင့် မ၊ မပစ်ရ", "km": "ឧបករណ៍មានខ្សែចង លើកសម្ភារៈដោយរ៉ក/ខ្សែ ហាមបោះ", "lo": "ເຄື່ອງມືມີສາຍຄ້ອງ ຍົກວັດສະດຸດ້ວຍຮອກ/ເຊືອກ ຫ້າມໂຍນ"}, "crit": false, "ill": "toollanyard"}, {"code": "H10", "text": "กั้นเขตอันตรายด้านล่าง (ของตก)", "t": {"my": "အောက်ဘက် အန္တရာယ်ဇုန်ကို ကာ (ပစ္စည်းကျ)", "km": "រាំងតំបន់គ្រោះថ្នាក់ខាងក្រោម (របស់ធ្លាក់)", "lo": "ກັ້ນເຂດອັນຕະລາຍດ້ານລຸ່ມ (ຂອງຕົກ)"}, "crit": false, "ill": "below"}, {"code": "H11", "text": "ห่างสายไฟฟ้าแรงสูง ≥ 3 ม. หรือประสานการไฟฟ้าหุ้มสาย", "t": {"my": "ဗို့အားမြင့်ကြိုးမှ ≥ ၃ မီတာ ဝေး သို့မဟုတ် လျှပ်စစ်ဌာနနှင့် ညှိ၍ ကြိုးအုပ်", "km": "នៅឆ្ងាយខ្សែភ្លើងតង់ស្យុងខ្ពស់ ≥ ៣ម ឬសម្របសម្រួលអគ្គិសនីរុំខ្សែ", "lo": "ຫ່າງສາຍໄຟແຮງສູງ ≥ 3 ມ. ຫຼື ປະສານການໄຟຟ້າຫຸ້ມສາຍ"}, "crit": true, "na": true, "ill": "powerline"}, {"code": "H12", "text": "ไม่มีฝน หลังคาไม่เปียก ลมไม่เกินเกณฑ์", "t": {"my": "မိုးမရွာ၊ အမိုးမစို၊ လေ စံနှုန်းမကျော်", "km": "គ្មានភ្លៀង ដំបូលមិនសើម ខ្យល់មិនលើសកម្រិត", "lo": "ບໍ່ມີຝົນ ຫຼັງຄາບໍ່ປຽກ ລົມບໍ່ເກີນເກນ"}, "crit": true, "ill": "rain"}], "rules": [{"code": "HR1", "text": "คล้องเกี่ยว 100% ตลอดเวลา รวมตอนย้ายจุด", "t": {"my": "အမြဲ ၁၀၀% ချိတ်ထား၊ နေရာရွှေ့စဉ်လည်း", "km": "ចងជាប់ 100% គ្រប់ពេល រួមទាំងពេលផ្លាស់ទី", "lo": "ຄ້ອງຕະຫຼອດ 100% ລວມຕອນຍ້າຍຈຸດ"}, "ill": "harness"}, {"code": "HR2", "text": "เดินบนท้องลอน/แป/ทางเดิน ไม่เหยียบกลางแผ่น", "t": {"my": "အမိုးလှိုင်းအောက်ခြေ/ပုလင်/လမ်းပေါ် လျှောက်၊ ပြားအလယ်မနင်း", "km": "ដើរលើបាតរលក/ដំបូល/ផ្លូវដើរ មិនជាន់កណ្តាលសន្លឹក", "lo": "ຍ່າງເທິງທ້ອງລອນ/ແປ/ທາງຍ່າງ ບໍ່ຢຽບກາງແຜ່ນ"}, "ill": "walkway"}, {"code": "HR3", "text": "ได้ยินฟ้าร้อง → ลงทันที รอ 30 นาที (กฎ 30/30)", "t": {"my": "မိုးချိန်းသံကြားလျှင် ချက်ချင်းဆင်း၊ မိနစ် ၃၀ စောင့် (30/30)", "km": "ឮផ្គរលាន់ → ចុះភ្លាម រង់ចាំ ៣០នាទី (30/30)", "lo": "ໄດ້ຍິນຟ້າຮ້ອງ → ລົງທັນທີ ລໍ 30 ນາທີ (30/30)"}, "ill": "rain"}]}, {"code": "LD", "when": "ladder", "icon": "ladder", "title": "บันได", "items": [{"code": "LD1", "text": "ไม่ใช้บันไดไม้หรือบันไดดัดแปลง", "t": {"my": "သစ်သားလှေကား သို့မဟုတ် ပြုပြင်ထားသောလှေကား မသုံးရ", "km": "មិនប្រើជណ្តើរឈើ ឬជណ្តើរកែច្នៃ", "lo": "ບໍ່ໃຊ້ຂັ້ນໄດໄມ້ ຫຼື ຂັ້ນໄດດັດແປງ"}, "crit": true, "ill": "ladder"}, {"code": "LD2", "text": "ตรวจสภาพก่อนใช้: ขั้น ขา ตัวล็อก ยางกันลื่น", "t": {"my": "အသုံးမပြုမီ စစ်: အဆင့်၊ ခြေ၊ လော့ခ်၊ ချော်ခံရာဘာ", "km": "ពិនិត្យមុនប្រើ: កាំ ជើង សោ កៅស៊ូការពាររអិល", "lo": "ກວດກ່ອນໃຊ້: ຂັ້ນ ຂາ ຕົວລັອກ ຢາງກັນລື່ນ"}, "crit": false, "ill": "ladder"}, {"code": "LD6", "text": "งานไฟฟ้าใช้บันไดไฟเบอร์กลาส", "t": {"my": "လျှပ်စစ်အလုပ်တွင် ဖိုက်ဘာဂလပ်စ်လှေကား သုံး", "km": "ការងារអគ្គិសនីប្រើជណ្តើរ Fiberglass", "lo": "ວຽກໄຟຟ້າໃຊ້ຂັ້ນໄດໄຟເບີກລາດ"}, "crit": true, "na": true, "ill": "ladder_fiber"}], "rules": [{"code": "LR1", "text": "บันไดพาด: มุม 68–75° (1:4) ปลายยื่นเลยจุดพาด ≥ 1 ม. หรือผูกยึดด้านบน", "t": {"my": "မှီလှေကား: ထောင့် ၆၈–၇၅° (၁:၄)၊ ထိပ် ≥ ၁ မီတာ ကျော်၊ သို့မဟုတ် အပေါ်ချည်", "km": "ជណ្តើរផ្អែក: មុំ 68–75° (1:4) ចុងលើសចំណុចផ្អែក ≥ 1ម ឬចងខាងលើ", "lo": "ຂັ້ນໄດພາດ: ມຸມ 68–75° (1:4) ປາຍຍື່ນເລີຍ ≥ 1 ມ. ຫຼື ມັດຍຶດດ້ານເທິງ"}, "ill": "ladder_angle"}, {"code": "LR2", "text": "ขึ้นทีละ 1 คน มีคนจับฐาน ใช้ 3 จุดสัมผัส", "t": {"my": "တစ်ကြိမ် ၁ ယောက်တက်၊ အောက်ခြေကိုင်သူရှိ၊ ၃ နေရာထိ", "km": "ឡើងម្តងម្នាក់ មានអ្នកកាន់ជើង ប៉ះ ៣ចំណុច", "lo": "ຂຶ້ນເທື່ອລະ 1 ຄົນ ມີຄົນຈັບຖານ ໃຊ້ 3 ຈຸດສຳຜັດ"}, "ill": "ladder"}, {"code": "LR3", "text": "บันไดทรงเอ: กางสุด ล็อก ไม่ยืน 3 ขั้นบนสุด", "t": {"my": "A လှေကား: အပြည့်ဖြန့်၊ လော့ခ်၊ အပေါ်ဆုံး ၃ ဆင့် မရပ်", "km": "ជណ្តើរ A: លាតពេញ ចាក់សោ មិនឈរ ៣កាំខាងលើ", "lo": "ຂັ້ນໄດ A: ກາງສຸດ ລັອກ ບໍ່ຢືນ 3 ຂັ້ນເທິງສຸດ"}, "ill": "ladder_a"}, {"code": "LR4", "text": "ยืนสูง ≥ 1.8 ม. และใช้ 3 จุดสัมผัสไม่ได้ → สวม Harness", "t": {"my": "≥ ၁.၈ မီတာ မြင့်ပြီး ၃ နေရာမထိနိုင်လျှင် Harness ဝတ်", "km": "ឈរខ្ពស់ ≥ 1.8ម ហើយប៉ះ ៣ចំណុចមិនបាន → ពាក់ Harness", "lo": "ຢືນສູງ ≥ 1.8 ມ. ແລະ ໃຊ້ 3 ຈຸດບໍ່ໄດ້ → ໃສ່ Harness"}, "ill": "harness"}, {"code": "LR5", "text": "ไม่ตั้งบนนั่งร้าน ใกล้ขอบ/ช่องเปิด หรือขวางประตู/ทางเดิน", "t": {"my": "ငြမ်းပေါ်၊ အစွန်း/အပေါက်နား၊ တံခါး/လမ်းကို မပိတ်ဘဲ မထား", "km": "មិនដាក់លើរន្ទា ក្បែរគែម/រន្ធ ឬរារាំងទ្វារ/ផ្លូវ", "lo": "ບໍ່ຕັ້ງເທິງນັ່ງຮ້ານ ໃກ້ຂອບ/ຊ່ອງເປີດ ຫຼື ຂວາງປະຕູ/ທາງຍ່າງ"}, "ill": "ladder"}]}, {"code": "SC", "when": "scaffold", "icon": "scaffold", "title": "นั่งร้าน", "items": [{"code": "SC1", "text": "มีป้ายรับรองผลตรวจวันนี้ (สีใดก็ได้ ระบุชัดว่าตรวจแล้วใช้งานได้) โดยผู้ผ่านอบรมผู้ตรวจนั่งร้าน", "t": {"my": "ယနေ့ စစ်ဆေးပြီး ဆိုင်းဘုတ် (အရောင်မရွေး၊ အသုံးပြုနိုင်ကြောင်း ရှင်းလင်း) ငြမ်းစစ်ဆေးသူမှ", "km": "មានស្លាកបញ្ជាក់ការត្រួតពិនិត្យថ្ងៃនេះ (ពណ៌ណាក៏បាន) ដោយអ្នកត្រួតពិនិត្យរន្ទា", "lo": "ມີປ້າຍຮັບຮອງຜົນກວດມື້ນີ້ (ສີໃດກໍໄດ້) ໂດຍຜູ້ກວດນັ່ງຮ້ານ"}, "crit": true, "ill": "scaffold_tag"}, {"code": "SC2", "text": "พื้นปูเต็ม ผูกแน่น ทางเดินกว้าง ≥ 45 ซม.", "t": {"my": "ကြမ်းခင်းပြည့်၊ တင်းကျပ်ချည်၊ လမ်း ≥ ၄၅ စင်တီ", "km": "កម្រាលពេញ ចងជាប់ ផ្លូវដើរ ≥ 45សម", "lo": "ພື້ນປູເຕັມ ມັດແໜ້ນ ທາງຍ່າງ ≥ 45 ຊມ."}, "crit": true, "ill": "scaffold"}, {"code": "SC3", "text": "ราวกันตกครบ (บน 90–110 · กลาง 45–55 ซม. · Toe board)", "t": {"my": "လက်ရန်းပြည့်စုံ (အပေါ် ၉၀–၁၁၀ · အလယ် ၄၅–၅၅ · Toe board)", "km": "របាំងការពារគ្រប់ (លើ 90–110 · កណ្តាល 45–55 · Toe board)", "lo": "ຮາວກັນຕົກຄົບ (ເທິງ 90–110 · ກາງ 45–55 · Toe board)"}, "crit": true, "ill": "guardrail"}, {"code": "SC4", "text": "ยึดโยงกับอาคารเมื่อสูง > 4 ม. หรือ > 3 เท่าฐาน", "t": {"my": "> ၄ မီတာ သို့မဟုတ် အခြေ၏ ၃ ဆ ထက်မြင့်လျှင် အဆောက်အဦနှင့် ချည်", "km": "ចងភ្ជាប់អគារពេលខ្ពស់ > 4ម ឬ > 3ដងនៃមូលដ្ឋាន", "lo": "ຍຶດໂຍງກັບອາຄານເມື່ອສູງ > 4 ມ. ຫຼື > 3 ເທົ່າຖານ"}, "crit": true, "na": true, "ill": "scaffold"}, {"code": "SC5", "text": "แผ่นรองฐานทุกต้น ขาปรับระดับไม่เกินกำหนด", "t": {"my": "တိုင်တိုင်းတွင် အခြေခံပြား၊ ချိန်ညှိခြေ ကန့်သတ်ချက်မကျော်", "km": "បន្ទះទ្រគ្រប់ជើង ជើងតម្រឹមមិនលើសកំណត់", "lo": "ແຜ່ນຮອງຖານທຸກຕົ້ນ ຂາປັບລະດັບບໍ່ເກີນກຳນົດ"}, "crit": false, "ill": "baseplate"}, {"code": "SC9", "text": "สูง > 4 ม. มีแบบคำนวณโดยวิศวกร", "t": {"my": "> ၄ မီတာ မြင့်လျှင် အင်ဂျင်နီယာ တွက်ချက်ပုံစံ ရှိ", "km": "ខ្ពស់ > 4ម មានគំនូរគណនាដោយវិស្វករ", "lo": "ສູງ > 4 ມ. ມີແບບຄຳນວນໂດຍວິສະວະກອນ"}, "crit": false, "na": true, "ill": "engineer"}], "rules": [{"code": "SR1", "text": "ขึ้นลงทางบันไดด้านใน ไม่ปีนโครงด้านนอก", "t": {"my": "အတွင်းလှေကားဖြင့် အတက်အဆင်း၊ အပြင်ဘောင်မတက်", "km": "ឡើងចុះតាមជណ្តើរខាងក្នុង មិនឡើងស៊ុមខាងក្រៅ", "lo": "ຂຶ້ນລົງທາງຂັ້ນໄດດ້ານໃນ ບໍ່ປີນໂຄງດ້ານນອກ"}, "ill": "scaffold"}, {"code": "SR2", "text": "นั่งร้านล้อ: ล็อกทุกล้อ ห้ามเข็นขณะมีคนอยู่บน", "t": {"my": "ဘီးငြမ်း: ဘီးအားလုံးလော့ခ်၊ လူရှိစဉ် မတွန်းရ", "km": "រន្ទាកង់: ចាក់សោគ្រប់កង់ ហាមរុញពេលមានមនុស្សលើ", "lo": "ນັ່ງຮ້ານລໍ້: ລັອກທຸກລໍ້ ຫ້າມເຂັນຂະນະມີຄົນຢູ່ເທິງ"}, "ill": "scaffold"}, {"code": "SR3", "text": "คล้อง Lanyard กับคาน/ราว/ตงเท่านั้น", "t": {"my": "Lanyard ကို ရက်မ/လက်ရန်း/ထုပ်တွင်သာ ချိတ်", "km": "ចង Lanyard នឹងធ្នឹម/របាំង/ផ្ទាំងប៉ុណ្ណោះ", "lo": "ຄ້ອງ Lanyard ກັບຄານ/ຮາວ/ຕົງເທົ່ານັ້ນ"}, "ill": "harness"}]}, {"code": "CE", "when": "confined", "icon": "confined", "title": "ในฝ้า / ใต้หลังคา", "items": [{"code": "CE1", "text": "ตัดไฟวงจรที่เกี่ยวข้อง + ล็อก/แขวนป้าย (ถ่ายรูปตู้ไฟ)", "t": {"my": "သက်ဆိုင်ရာ ဆားကစ် မီးဖြတ် + လော့ခ်/ဆိုင်းဘုတ်ချိတ် (မီးခလုတ်ဘုတ် ဓာတ်ပုံ)", "km": "ផ្តាច់ភ្លើងសៀគ្វីពាក់ព័ន្ធ + ចាក់សោ/ព្យួរស្លាក (ថតរូបតូភ្លើង)", "lo": "ຕັດໄຟວົງຈອນທີ່ກ່ຽວຂ້ອງ + ລັອກ/ແຂວນປ້າຍ (ຖ່າຍຮູບຕູ້ໄຟ)"}, "crit": true, "lsr": 2, "ill": "loto"}, {"code": "CE2", "text": "ระบายอากาศ/พัดลมเป่าเข้าในฝ้า ไฟส่องสว่างพอ", "t": {"my": "မျက်နှာကျက်အတွင်း လေဝင်လေထွက်/ပန်ကာ၊ အလင်းလုံလောက်", "km": "ខ្យល់ចេញចូល/កង្ហារផ្លុំចូលពិដាន ពន្លឺគ្រប់គ្រាន់", "lo": "ລະບາຍອາກາດ/ພັດລົມເປົ່າເຂົ້າໃນຝ້າ ແສງສະຫວ່າງພໍ"}, "crit": true, "ill": "fan"}, {"code": "CE3", "text": "มีคนเฝ้าด้านนอกช่องเปิดตลอดเวลา (สื่อสารได้)", "t": {"my": "အပေါက်အပြင်တွင် စောင့်ကြည့်သူ အမြဲရှိ (ဆက်သွယ်နိုင်)", "km": "មានអ្នកយាមខាងក្រៅរន្ធគ្រប់ពេល (ទាក់ទងបាន)", "lo": "ມີຄົນເຝົ້າດ້ານນອກຊ່ອງເປີດຕະຫຼອດ (ສື່ສານໄດ້)"}, "crit": true, "ill": "watch"}, {"code": "CE4", "text": "หน้ากาก N95 แว่น เสื้อแขนยาว (ใยแก้ว/ฝุ่น)", "t": {"my": "N95 မျက်နှာဖုံး၊ မျက်မှန်၊ လက်ရှည်အင်္ကျီ (ဖန်မျှင်/ဖုန်)", "km": "ម៉ាស N95 វ៉ែនតា អាវដៃវែង (សរសៃកញ្ចក់/ធូលី)", "lo": "ໜ້າກາກ N95 ແວ່ນ ເສື້ອແຂນຍາວ (ໃຍແກ້ວ/ຝຸ່ນ)"}, "crit": false, "ill": "mask"}, {"code": "CE5", "text": "น้ำดื่ม + รอบพัก", "t": {"my": "သောက်ရေ + အနားယူချိန်", "km": "ទឹកផឹក + វេនសម្រាក", "lo": "ນ້ຳດື່ມ + ຮອບພັກ"}, "crit": false, "ill": "water"}, {"code": "CE6", "text": "ปูแผ่นทางเดินบนโครงคร่าว", "t": {"my": "ဘောင်ပေါ်တွင် လမ်းလျှောက်ပြား ခင်း", "km": "ក្រាលបន្ទះផ្លូវដើរលើស៊ុម", "lo": "ປູແຜ່ນທາງຍ່າງເທິງໂຄງຄ່າວ"}, "crit": true, "ill": "ceiling_walk", "setup": true}], "rules": [{"code": "CR1", "text": "เดินบนโครง/แผ่นทางเดินเท่านั้น ห้ามเหยียบแผ่นฝ้า", "t": {"my": "ဘောင်/လမ်းလျှောက်ပြားပေါ်သာ လျှောက်၊ မျက်နှာကျက်ပြား မနင်းရ", "km": "ដើរលើស៊ុម/បន្ទះផ្លូវដើរប៉ុណ្ណោះ ហាមជាន់ពិដាន", "lo": "ຍ່າງເທິງໂຄງ/ແຜ່ນທາງຍ່າງເທົ່ານັ້ນ ຫ້າມຢຽບແຜ່ນຝ້າ"}, "ill": "ceiling_walk"}, {"code": "CR2", "text": "อยู่ในฝ้าต่อเนื่องไม่เกิน 30 นาที/รอบ", "t": {"my": "မျက်နှာကျက်အတွင်း တစ်ကြိမ် မိနစ် ၃၀ ထက်မပို", "km": "នៅក្នុងពិដានជាប់គ្នាមិនលើស ៣០នាទី/វេន", "lo": "ຢູ່ໃນຝ້າຕໍ່ເນື່ອງບໍ່ເກີນ 30 ນາທີ/ຮອບ"}, "ill": "water"}, {"code": "CR3", "text": "ไม่ทำคนเดียว เรียกชื่อกันทุก 10–15 นาที", "t": {"my": "တစ်ယောက်တည်း မလုပ်၊ ၁၀–၁၅ မိနစ်တိုင်း နာမည်ခေါ်", "km": "មិនធ្វើម្នាក់ឯង ហៅឈ្មោះគ្នារៀងរាល់ ១០–១៥នាទី", "lo": "ບໍ່ເຮັດຄົນດຽວ ເອີ້ນຊື່ກັນທຸກ 10–15 ນາທີ"}, "ill": "buddy"}]}, {"code": "O", "when": "occupied", "icon": "home", "title": "บ้านมีผู้อยู่อาศัย", "items": [{"code": "O1", "text": "แจ้งเจ้าของบ้านถึงจุดอันตราย เวลาตัดไฟ/น้ำ และพื้นที่ห้ามเข้า", "t": {"my": "အိမ်ရှင်ကို အန္တရာယ်နေရာ၊ မီး/ရေဖြတ်ချိန်၊ ဝင်ခွင့်မရှိနေရာ ပြော", "km": "ប្រាប់ម្ចាស់ផ្ទះពីចំណុចគ្រោះថ្នាក់ ម៉ោងផ្តាច់ភ្លើង/ទឹក និងតំបន់ហាមចូល", "lo": "ແຈ້ງເຈົ້າຂອງເຮືອນເຖິງຈຸດອັນຕະລາຍ ເວລາຕັດໄຟ/ນ້ຳ ແລະ ພື້ນທີ່ຫ້າມເຂົ້າ"}, "crit": true, "ill": "owner"}, {"code": "O2", "text": "กั้นเขตอันตรายใต้จุดทำงาน เด็กและสัตว์เลี้ยงเข้าไม่ได้", "t": {"my": "အလုပ်နေရာအောက် အန္တရာယ်ဇုန်ကာ၊ ကလေး/အိမ်မွေးတိရစ္ဆာန် မဝင်နိုင်", "km": "រាំងតំបន់គ្រោះថ្នាក់ក្រោមកន្លែងធ្វើការ កុមារនិងសត្វចិញ្ចឹមចូលមិនបាន", "lo": "ກັ້ນເຂດອັນຕະລາຍໃຕ້ຈຸດເຮັດວຽກ ເດັກ ແລະ ສັດລ້ຽງເຂົ້າບໍ່ໄດ້"}, "crit": true, "ill": "kids"}, {"code": "O3", "text": "ปิดคลุมทรัพย์สิน/รถของเจ้าของบ้าน", "t": {"my": "အိမ်ရှင်၏ ပစ္စည်း/ကားကို ဖုံးအုပ်", "km": "គ្របទ្រព្យសម្បត្តិ/ឡានម្ចាស់ផ្ទះ", "lo": "ປົກຄຸມຊັບສິນ/ລົດຂອງເຈົ້າຂອງເຮືອນ"}, "crit": false, "na": true, "ill": "cover"}, {"code": "O4", "text": "ทางเข้าออกไม่ถูกปิด สายไฟ/สายยางไม่พาดทางเดิน", "t": {"my": "အဝင်အထွက်မပိတ်၊ ကြိုး/ပိုက်များ လမ်းပေါ်မဖြတ်", "km": "ផ្លូវចេញចូលមិនបិទ ខ្សែភ្លើង/បំពង់មិនឆ្លងផ្លូវ", "lo": "ທາງເຂົ້າອອກບໍ່ຖືກປິດ ສາຍໄຟ/ສາຍຢາງບໍ່ພາດທາງຍ່າງ"}, "crit": false, "ill": "path"}], "rules": [{"code": "OR1", "text": "หยุดงานทันทีเมื่อมีคนเข้าเขตอันตราย", "t": {"my": "အန္တရာယ်ဇုန်ထဲ လူဝင်လျှင် ချက်ချင်းရပ်", "km": "ឈប់ភ្លាមពេលមានមនុស្សចូលតំបន់គ្រោះថ្នាក់", "lo": "ຢຸດວຽກທັນທີເມື່ອມີຄົນເຂົ້າເຂດອັນຕະລາຍ"}, "ill": "kids"}, {"code": "OR2", "text": "ไม่ทิ้งเครื่องมือ/บันไดไว้ให้เด็กเข้าถึง (รวมพักเที่ยง)", "t": {"my": "ကိရိယာ/လှေကားကို ကလေးရောက်နိုင်သည့်နေရာ မထား (နေ့လည်စာချိန်လည်း)", "km": "មិនទុកឧបករណ៍/ជណ្តើរឱ្យកុមារប៉ះបាន (រួមពេលសម្រាកថ្ងៃត្រង់)", "lo": "ບໍ່ປະເຄື່ອງມື/ຂັ້ນໄດໃຫ້ເດັກເຂົ້າເຖິງ (ລວມພັກທ່ຽງ)"}, "ill": "ladder"}, {"code": "OR3", "text": "ควบคุมเสียงและฝุ่น ตัด/เจียรนอกบ้าน", "t": {"my": "အသံနှင့်ဖုန် ထိန်း၊ ဖြတ်/ကြိတ် အိမ်အပြင်တွင်", "km": "គ្រប់គ្រងសំឡេងនិងធូលី កាត់/កិននៅក្រៅផ្ទះ", "lo": "ຄວບຄຸມສຽງ ແລະ ຝຸ່ນ ຕັດ/ເຈຍນອກເຮືອນ"}, "ill": "mask"}]}, {"code": "E", "when": "electric", "icon": "electric", "title": "ไฟฟ้า", "items": [{"code": "E1", "text": "ตัดไฟ + ล็อก/แขวนป้าย กุญแจอยู่กับผู้ทำงาน (ถ่ายรูป)", "t": {"my": "မီးဖြတ် + လော့ခ်/ဆိုင်းဘုတ်၊ သော့ကို အလုပ်သမားကိုင် (ဓာတ်ပုံ)", "km": "ផ្តាច់ភ្លើង + ចាក់សោ/ព្យួរស្លាក កូនសោនៅអ្នកធ្វើការ (ថតរូប)", "lo": "ຕັດໄຟ + ລັອກ/ແຂວນປ້າຍ ກະແຈຢູ່ກັບຜູ້ເຮັດວຽກ (ຖ່າຍຮູບ)"}, "crit": true, "lsr": 2, "ill": "loto"}, {"code": "E2", "text": "วัดยืนยันไม่มีไฟด้วยเครื่องวัดก่อนแตะ", "t": {"my": "မထိမီ မီတာဖြင့် မီးမရှိကြောင်း တိုင်းအတည်ပြု", "km": "វាស់បញ្ជាក់គ្មានភ្លើងមុនប៉ះ", "lo": "ວັດຢືນຢັນບໍ່ມີໄຟດ້ວຍເຄື່ອງວັດກ່ອນແຕະ"}, "crit": true, "ill": "meter"}, {"code": "E3", "text": "ผู้ต่อไฟมีใบรับรองช่างไฟฟ้า", "t": {"my": "ဝါယာဆက်သူတွင် လျှပ်စစ်ပညာရှင်လက်မှတ်ရှိ", "km": "អ្នកភ្ជាប់ភ្លើងមានវិញ្ញាបនបត្រជាងអគ្គិសនី", "lo": "ຜູ້ຕໍ່ໄຟມີໃບຮັບຮອງຊ່າງໄຟຟ້າ"}, "crit": true, "ill": "cert"}, {"code": "E4", "text": "เครื่องมือหุ้มฉนวน ถุงมือฉนวนตามงาน", "t": {"my": "လျှပ်ကာကိရိယာ၊ လျှပ်ကာလက်အိတ်", "km": "ឧបករណ៍មានអ៊ីសូឡង់ ស្រោមដៃអ៊ីសូឡង់", "lo": "ເຄື່ອງມືຫຸ້ມສນວນ ຖົງມືສນວນ"}, "crit": false, "ill": "insulated"}, {"code": "E5", "text": "โซลาร์: ปิด DC/AC isolator คลุมแผงก่อนต่อสาย", "t": {"my": "ဆိုလာ: DC/AC isolator ပိတ်၊ ကြိုးမဆက်မီ ပြားဖုံး", "km": "សូឡា: បិទ DC/AC isolator គ្របបន្ទះមុនភ្ជាប់ខ្សែ", "lo": "ໂຊລາ: ປິດ DC/AC isolator ປົກແຜງກ່ອນຕໍ່ສາຍ"}, "crit": true, "na": true, "ill": "solar"}], "rules": [{"code": "ER1", "text": "ห้ามทำงานไฟฟ้าขณะฝนตก/มือเปียก", "t": {"my": "မိုးရွာစဉ်/လက်စိုစဉ် လျှပ်စစ်အလုပ် မလုပ်ရ", "km": "ហាមធ្វើការអគ្គិសនីពេលភ្លៀង/ដៃសើម", "lo": "ຫ້າມເຮັດວຽກໄຟຟ້າຂະນະຝົນຕົກ/ມືປຽກ"}, "ill": "rain"}, {"code": "ER2", "text": "ห้ามปลดล็อก/ป้ายของคนอื่น", "t": {"my": "အခြားသူ၏ လော့ခ်/ဆိုင်းဘုတ်ကို မဖြုတ်ရ", "km": "ហាមដោះសោ/ស្លាករបស់អ្នកដទៃ", "lo": "ຫ້າມປົດລັອກ/ປ້າຍຂອງຄົນອື່ນ"}, "ill": "loto"}, {"code": "ER3", "text": "แจ้งทุกคนและเจ้าของบ้านก่อนจ่ายไฟทดสอบ", "t": {"my": "စမ်းသပ်မီးမပေးမီ အားလုံးနှင့်အိမ်ရှင်ကို ပြော", "km": "ប្រាប់អ្នករាល់គ្នានិងម្ចាស់ផ្ទះមុនបើកភ្លើងសាកល្បង", "lo": "ແຈ້ງທຸກຄົນ ແລະ ເຈົ້າຂອງເຮືອນກ່ອນຈ່າຍໄຟທົດສອບ"}, "ill": "owner"}]}, {"code": "W", "when": "hot", "icon": "fire", "title": "ประกายไฟ", "items": [{"code": "W1", "text": "ถังดับเพลิงพร้อมใช้อยู่ข้างจุดทำงาน", "t": {"my": "အလုပ်နေရာဘေးတွင် မီးသတ်ဘူး အသင့်", "km": "បំពង់ពន្លត់អគ្គិភ័យនៅក្បែរកន្លែងធ្វើការ", "lo": "ຖັງດັບເພີງພ້ອມໃຊ້ຢູ່ຂ້າງຈຸດເຮັດວຽກ"}, "crit": true, "ill": "extinguisher"}, {"code": "W2", "text": "เคลียร์วัสดุติดไฟรอบจุดทำงาน หรือคลุมผ้ากันไฟ", "t": {"my": "အလုပ်နေရာပတ်လည် မီးလောင်လွယ်ပစ္စည်း ဖယ် သို့မဟုတ် မီးခံစကြိုင်ဖုံး", "km": "សម្អាតវត្ថុងាយឆេះជុំវិញ ឬគ្របក្រណាត់ការពារភ្លើង", "lo": "ເກັບວັດສະດຸຕິດໄຟອ້ອມຈຸດເຮັດວຽກ ຫຼື ປົກຜ້າກັນໄຟ"}, "crit": true, "ill": "combustible"}, {"code": "W3", "text": "ตู้เชื่อม/สายเชื่อม/สายดินสภาพดี เครื่องเจียรมีการ์ด", "t": {"my": "ဂဟေစက်/ကြိုး/မြေကြိုး ကောင်း၊ ကြိတ်စက်တွင် အကာပါ", "km": "ម៉ាស៊ីនផ្សារ/ខ្សែ/ខ្សែដី ល្អ ម៉ាស៊ីនកិនមានរបាំង", "lo": "ຕູ້ເຊື່ອມ/ສາຍເຊື່ອມ/ສາຍດິນສະພາບດີ ເຄື່ອງເຈຍມີກາດ"}, "crit": false, "ill": "welder"}, {"code": "W4", "text": "ถังแก๊สตั้งตรง ยึดแน่น มีวาล์วกันไฟย้อน", "t": {"my": "ဓာတ်ငွေ့ဘူး မတ်မတ်၊ တင်းကျပ်၊ မီးပြန်ကာ ဗားရှိ", "km": "ធុងហ្គាសឈរត្រង់ ចងជាប់ មានវ៉ាល់ការពារភ្លើងត្រឡប់", "lo": "ຖັງແກັສຕັ້ງຊື່ ຍຶດແໜ້ນ ມີວາວກັນໄຟຍ້ອນ"}, "crit": false, "na": true, "ill": "gas"}, {"code": "W5", "text": "PPE: หน้ากากเชื่อม/เฟซชิลด์ ถุงมือหนัง เสื้อแขนยาว", "t": {"my": "PPE: ဂဟေမျက်နှာဖုံး/Face shield၊ သားရေလက်အိတ်၊ လက်ရှည်", "km": "PPE: របាំងផ្សារ/Face shield ស្រោមដៃស្បែក អាវដៃវែង", "lo": "PPE: ໜ້າກາກເຊື່ອມ/ເຟສຊິວ ຖົງມືໜັງ ເສື້ອແຂນຍາວ"}, "crit": false, "ill": "shield"}, {"code": "W6", "text": "ฉากกั้นสะเก็ดไฟ/แสงเชื่อม", "t": {"my": "မီးပွား/ဂဟေအလင်း ကာရံ", "km": "របាំងការពារផ្កាភ្លើង/ពន្លឺផ្សារ", "lo": "ສາກກັ້ນສະເກັດໄຟ/ແສງເຊື່ອມ"}, "crit": false, "na": true, "ill": "shield"}], "rules": [{"code": "WR1", "text": "มีคนเฝ้าไฟระหว่างทำ และหลังเสร็จ 30 นาที", "t": {"my": "လုပ်နေစဉ်နှင့် ပြီးနောက် မိနစ် ၃၀ မီးစောင့်သူရှိ", "km": "មានអ្នកយាមភ្លើងពេលធ្វើ និង ៣០នាទីក្រោយ", "lo": "ມີຄົນເຝົ້າໄຟລະຫວ່າງເຮັດ ແລະ ຫຼັງແລ້ວ 30 ນາທີ"}, "ill": "watch"}, {"code": "WR2", "text": "ห้ามงานประกายไฟบนหลังคา/ในฝ้า ถ้าไม่ได้รับอนุมัติเพิ่ม", "t": {"my": "ထပ်ဆောင်းခွင့်မရှိလျှင် အမိုး/မျက်နှာကျက်တွင် မီးပွားအလုပ် မလုပ်ရ", "km": "ហាមការងារផ្កាភ្លើងលើដំបូល/ក្នុងពិដាន បើគ្មានការអនុញ្ញាតបន្ថែម", "lo": "ຫ້າມວຽກປະກາຍໄຟເທິງຫຼັງຄາ/ໃນຝ້າ ຖ້າບໍ່ໄດ້ຮັບອະນຸມັດເພີ່ມ"}, "ill": "combustible"}]}, {"code": "L", "when": "lifting", "icon": "lift", "title": "ยกและขนย้าย", "items": [{"code": "L1", "text": "รอก/เครื่องยก/สลิง/เชือก สภาพดี ระบุพิกัด ไม่เกินพิกัด", "t": {"my": "ဘီး/ မ စက်/ ဝါယာကြိုး/ကြိုး ကောင်း၊ ဝန်ကန့်သတ်ချက်ပါ၊ မကျော်", "km": "រ៉ក/ម៉ាស៊ីនលើក/ខ្សែលួស/ខ្សែ ល្អ មានកម្រិតផ្ទុក មិនលើស", "lo": "ຮອກ/ເຄື່ອງຍົກ/ສະລິງ/ເຊືອກ ສະພາບດີ ລະບຸພິກັດ ບໍ່ເກີນພິກັດ"}, "crit": true, "ill": "sling"}, {"code": "L2", "text": "กั้นพื้นที่ใต้จุดยก ห้ามคนอยู่ใต้ของแขวน", "t": {"my": "မနေရာအောက် ကာ၊ ချိတ်ထားသောပစ္စည်းအောက် လူမရှိရ", "km": "រាំងតំបន់ក្រោមចំណុចលើក ហាមមនុស្សនៅក្រោមរបស់ព្យួរ", "lo": "ກັ້ນພື້ນທີ່ໃຕ້ຈຸດຍົກ ຫ້າມຄົນຢູ່ໃຕ້ຂອງແຂວນ"}, "crit": true, "ill": "below"}, {"code": "L3", "text": "แผ่นยาว/ใหญ่ ยก ≥ 2 คน ใช้เชือกนำ (tagline)", "t": {"my": "ရှည်/ကြီးသောပြား ≥ ၂ ယောက် မ၊ လမ်းညွှန်ကြိုး (tagline) သုံး", "km": "សន្លឹកវែង/ធំ លើក ≥ ២នាក់ ប្រើខ្សែដឹកនាំ", "lo": "ແຜ່ນຍາວ/ໃຫຍ່ ຍົກ ≥ 2 ຄົນ ໃຊ້ເຊືອກນຳ"}, "crit": false, "ill": "lift2"}, {"code": "L4", "text": "จุดรับของบนหลังคามั่นคง คนรับคล้องสายกันตกแล้ว", "t": {"my": "အမိုးပေါ် လက်ခံနေရာ ခိုင်ခံ့၊ လက်ခံသူ ပြုတ်ကျကာကွယ်ကြိုးချိတ်ပြီး", "km": "ចំណុចទទួលលើដំបូលរឹងមាំ អ្នកទទួលបានចងខ្សែការពារធ្លាក់", "lo": "ຈຸດຮັບຂອງເທິງຫຼັງຄາໝັ້ນຄົງ ຄົນຮັບຄ້ອງສາຍກັນຕົກແລ້ວ"}, "crit": false, "na": true, "ill": "catcher"}], "rules": [{"code": "LRR1", "text": "คนสั่งยก 1 คน สัญญาณชัดเจน", "t": {"my": "မ အမိန့်ပေးသူ ၁ ယောက်၊ အချက်ပြ ရှင်းလင်း", "km": "អ្នកបញ្ជាលើក ១នាក់ សញ្ញាច្បាស់", "lo": "ຄົນສັ່ງຍົກ 1 ຄົນ ສັນຍານຊັດເຈນ"}, "ill": "lift2"}, {"code": "LRR2", "text": "หยุดยกแผ่นใหญ่เมื่อลมกระโชก ≥ 40 กม./ชม.", "t": {"my": "လေပြင်း ≥ ၄၀ ကီလို/နာရီ ဆိုလျှင် ပြားကြီး မ ခြင်း ရပ်", "km": "ឈប់លើកសន្លឹកធំពេលខ្យល់បក់ ≥ 40 គម/ម៉", "lo": "ຢຸດຍົກແຜ່ນໃຫຍ່ເມື່ອລົມກະໂຊກ ≥ 40 ກມ./ຊມ."}, "ill": "wind"}, {"code": "LRR3", "text": "ยกถูกท่า ของหนักเกินคนเดียวใช้ 2 คนหรืออุปกรณ์", "t": {"my": "မှန်ကန်စွာ မ၊ လေးလွန်းလျှင် ၂ ယောက် သို့မဟုတ် ကိရိယာ သုံး", "km": "លើកត្រឹមត្រូវ របស់ធ្ងន់ពេកប្រើ ២នាក់ ឬឧបករណ៍", "lo": "ຍົກຖືກທ່າ ຂອງໜັກເກີນຄົນດຽວໃຊ້ 2 ຄົນ ຫຼື ອຸປະກອນ"}, "ill": "lift2"}]}, {"code": "X", "when": "excavation", "icon": "dig", "title": "ขุด", "items": [{"code": "X1", "text": "ตรวจท่อน้ำ/ท่อแก๊ส/สายไฟใต้ดินก่อนขุด", "t": {"my": "မတူးမီ မြေအောက် ရေပိုက်/ဓာတ်ငွေ့ပိုက်/ကြိုး စစ်", "km": "ពិនិត្យបំពង់ទឹក/ហ្គាស/ខ្សែភ្លើងក្រោមដីមុនជីក", "lo": "ກວດທໍ່ນ້ຳ/ທໍ່ແກັສ/ສາຍໄຟໃຕ້ດິນກ່ອນຂຸດ"}, "crit": true, "ill": "pipe"}, {"code": "X2", "text": "ขุดลึก > 1.5 ม. ทำค้ำยันหรือผนังลาดเอียง", "t": {"my": "> ၁.၅ မီတာ နက်လျှင် ထောက်ကန် သို့မဟုတ် ဆင်ခြေလျှော", "km": "ជីកជ្រៅ > 1.5ម ធ្វើរនាំងទ្រ ឬជញ្ជាំងជម្រាល", "lo": "ຂຸດເລິກ > 1.5 ມ. ເຮັດຄ້ຳຍັນ ຫຼື ຝາຄ້ອຍ"}, "crit": true, "na": true, "ill": "trench"}], "rules": [{"code": "XR1", "text": "กั้นหลุม/ปิดฝาและติดป้ายทุกครั้งที่ออกจากหน้างาน", "t": {"my": "နေရာမှထွက်တိုင်း တွင်းကို ကာ/ဖုံးပြီး ဆိုင်းဘုတ်ကပ်", "km": "រាំង/គ្របរណ្តៅ និងបិទស្លាករាល់ពេលចេញ", "lo": "ກັ້ນຂຸມ/ປິດຝາ ແລະ ຕິດປ້າຍທຸກຄັ້ງທີ່ອອກຈາກໜ້າງານ"}, "ill": "barricade"}, {"code": "XR2", "text": "กองดินห่างขอบหลุม ≥ 0.6 ม.", "t": {"my": "မြေပုံကို တွင်းအစွန်းမှ ≥ ၀.၆ မီတာ ဝေး", "km": "គំនរដីឆ្ងាយពីគែមរណ្តៅ ≥ 0.6ម", "lo": "ກອງດິນຫ່າງຂອບຂຸມ ≥ 0.6 ມ."}, "ill": "trench"}]}, {"code": "K", "when": "chemical", "icon": "chem", "title": "สารเคมี", "items": [{"code": "K1", "text": "มี SDS ภาษาไทย อ่านแล้ว", "t": {"my": "ထိုင်းဘာသာ SDS ရှိပြီး ဖတ်ပြီး", "km": "មាន SDS ភាសាថៃ ហើយបានអាន", "lo": "ມີ SDS ພາສາໄທ ອ່ານແລ້ວ"}, "crit": true, "ill": "sds"}, {"code": "K2", "text": "PPE ตาม SDS", "t": {"my": "SDS အတိုင်း PPE", "km": "PPE តាម SDS", "lo": "PPE ຕາມ SDS"}, "crit": false, "ill": "ppe"}, {"code": "K3", "text": "ระบายอากาศ ห้ามประกายไฟใกล้สารไวไฟ", "t": {"my": "လေဝင်လေထွက်၊ မီးလောင်လွယ်ပစ္စည်းနား မီးပွားမရှိရ", "km": "ខ្យល់ចេញចូល ហាមផ្កាភ្លើងក្បែរសារធាតុងាយឆេះ", "lo": "ລະບາຍອາກາດ ຫ້າມປະກາຍໄຟໃກ້ສານໄວໄຟ"}, "crit": true, "ill": "fan"}], "rules": [{"code": "KR1", "text": "ปิดฝาภาชนะ ไม่ทิ้งให้เด็กเข้าถึง ไม่เทลงท่อระบาย", "t": {"my": "ဗူးအဖုံးပိတ်၊ ကလေးမရောက်စေ၊ မြောင်းထဲ မသွန်ရ", "km": "បិទគម្របធុង មិនទុកឱ្យកុមារប៉ះ មិនចាក់ចូលលូ", "lo": "ປິດຝາພາຊະນະ ບໍ່ປະໃຫ້ເດັກເຂົ້າເຖິງ ບໍ່ເທລົງທໍ່ລະບາຍ"}, "ill": "kids"}]}]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'closeout','[{"code": "Z1", "text": "ทุกคนลงจากที่สูง/ออกจากฝ้าครบ นับจำนวนคนแล้ว", "crit": true}, {"code": "Z2", "text": "ตัดไฟเครื่องมือ เก็บสายพ่วง คืนไฟบ้านอย่างปลอดภัย"}, {"code": "Z3", "text": "ปิดหลังคา/กันฝน เก็บบันได ปิดทางขึ้นนั่งร้าน (เด็กปีนไม่ได้)", "crit": true}, {"code": "Z4", "text": "ปิด/กั้นช่องเปิด หลุม จุดเปราะบาง ป้ายเตือนยังอยู่", "crit": true}, {"code": "Z5", "text": "เก็บเศษวัสดุ ไม่กีดขวางทางเข้าออก"}, {"code": "Z6", "text": "สารเคมี/แก๊สเก็บปิดฝาในที่ปลอดภัย"}, {"code": "Z7", "text": "งานประกายไฟ: เฝ้าไฟครบ 30 นาทีแล้ว"}, {"code": "Z8", "text": "จุดยึด/Lifeline ที่ทิ้งไว้ ติดป้ายห้ามใช้โดยคนอื่น"}]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'bbs','["คล้องเกี่ยว 100% ตลอดเวลาบนที่สูง (LSR 1)", "สวม Harness ถูกต้อง", "ไม่เหยียบจุดเปราะบาง", "ใช้บันไดถูกวิธี", "หมวกรัดสายคาง", "แว่น/เฟซชิลด์ขณะตัด เจียร เจาะ", "ถุงมือ · รองเท้านิรภัย", "ไม่ถอดการ์ดเครื่องมือ", "เครื่องมือบนที่สูงมีสายคล้อง", "ไม่ต่อไฟตรง/ไม่ใช้สายชำรุด (LSR 2)", "ยกของถูกท่า", "พื้นที่เป็นระเบียบ", "ไม่ใช้โทรศัพท์ขณะทำงานบนที่สูง/ใช้เครื่องมือ", "ขับรถปลอดภัย ผูกยึดของบนกระบะ (LSR 7)"]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'toolbox','["คล้องเกี่ยวตลอดเวลาเมื่ออยู่บนที่สูง รวมตอนย้ายจุด", "ตรวจบันไดก่อนใช้ทุกครั้ง มุมพาด 1:4 ยื่นเลยขอบ 1 เมตร", "หลังคาเปียก ลมแรง ฟ้าร้อง = ลงทันที", "ตัดไฟ ล็อก แขวนป้าย ก่อนแตะสายไฟทุกครั้ง", "ปลั๊กพ่วงต้องมี RCD และสายไม่ชำรุด", "ดื่มน้ำทุก 15–20 นาที พักในร่มเมื่ออากาศร้อนจัด", "ห้ามเหยียบแผ่นโปร่งแสงและแผ่นฝ้า เดินบนแปหรือทางเดินเท่านั้น", "กั้นพื้นที่ใต้จุดทำงาน ระวังเด็กและสัตว์เลี้ยงของบ้าน", "ยกแผ่นใหญ่ใช้ 2 คนและเชือกนำ หยุดยกเมื่อลมแรง", "งานเชื่อม/เจียร: ถังดับเพลิงข้างตัว เฝ้าไฟหลังเสร็จ 30 นาที", "สวมหมวกรัดสายคาง แว่นตา ถุงมือ ตลอดเวลา", "รู้เบอร์ 1669 และทางไปโรงพยาบาลใกล้ที่สุด"]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'selfdec','{"version": "draft-2026-10", "items": ["โรคหัวใจ หรือเจ็บแน่นหน้าอก", "ความดันโลหิตสูงที่ยังคุมไม่ได้", "โรคลมชัก หรือเคยชัก", "เวียนศีรษะ บ้านหมุน หรือเป็นลมหมดสติบ่อย", "โรคกลัวความสูง", "เบาหวานที่ต้องฉีดอินซูลิน หรือเคยน้ำตาลต่ำจนหมดสติ", "โรคหอบหืดที่ยังมีอาการ", "ปัญหาการมองเห็นที่แก้ไขด้วยแว่นไม่ได้", "ปัญหาการได้ยินรุนแรง", "ปัญหาการทรงตัว หรือหูชั้นในอักเสบ", "โรคกระดูกสันหลัง ข้อเข่า หรือข้อสะโพกที่จำกัดการเคลื่อนไหว", "เคยผ่าตัดใหญ่ภายใน 6 เดือน", "กล้ามเนื้ออ่อนแรง หรือมือสั่น", "โรคไตหรือตับที่ต้องรักษาต่อเนื่อง", "ใช้ยาที่ทำให้ง่วงซึมเป็นประจำ", "ดื่มสุราเป็นประจำ หรือเคยมีปัญหาจากการดื่ม", "นอนไม่หลับเรื้อรัง หรือนอนกรนรุนแรงจนง่วงกลางวัน", "โรคโลหิตจางรุนแรง", "เคยบาดเจ็บที่ศีรษะรุนแรง", "ตั้งครรภ์", "น้ำหนักตัวรวมอุปกรณ์เกินพิกัดของ Harness (ปกติ 140 กก.)", "อาการเจ็บป่วยอื่นที่แพทย์สั่งห้ามทำงานบนที่สูง"]}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'pdpa','{"version": "2026-10-draft", "title": "การเก็บและใช้ข้อมูลส่วนบุคคลใน SafeStart (ร่าง รอฝ่ายกฎหมายตรวจ)", "paragraphs": ["SafeStart เก็บข้อมูลเพื่อดูแลความปลอดภัยในการทำงานติดตั้ง: ชื่อ เบอร์โทร อีเมล บทบาท บริษัท รูปถ่ายหน้างาน ตำแหน่ง GPS ตอน check-in และประวัติการทำงาน", "ข้อมูลช่าง: ชื่อ รูปหน้า วันเกิด เลขบัตรท้าย 4 หลัก และค่ารหัสทางเดียว (hash) ของเลขบัตรเพื่อป้องกันการลงทะเบียนซ้ำ ระบบไม่เก็บสำเนาบัตร รูปบัตรที่ส่งมาตรวจถูกลบทันทีหลังตรวจ", "ข้อมูลสุขภาพ (ผลตรวจประจำวัน และแบบประเมินตนเองปีละครั้ง) ใช้คัดกรองก่อนขึ้นที่สูงเท่านั้น ค่าที่วัดเห็นเฉพาะผู้ดูแลบริษัทผู้รับเหมาและเจ้าหน้าที่ความปลอดภัย คำตอบแบบประเมินตนเองเห็นเฉพาะผู้ดูแลบริษัทผู้รับเหมา", "ข้อมูลเปิดเผยเฉพาะบริษัทในกลุ่ม SCG ที่จ้างงานคุณ หากมีการฝ่าฝืนกฎพิทักษ์ชีวิต บริษัทอื่นในกลุ่มเห็นเพียงข้อกฎ วันที่ และระดับโทษ", "รูปภาพเก็บ 60 วันในระบบหลักแล้วย้ายไปที่เก็บถาวร ข้อมูลอื่นเก็บตามระยะเวลาที่กฎหมายกำหนด คุณขอดู แก้ไข หรือถอนความยินยอมได้ที่เจ้าหน้าที่ความปลอดภัยของบริษัท"]}'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'lsr','["ป้องกันการตกจากที่สูง ≥ 1.8 ม.", "ตัดแยกพลังงาน ล็อก แขวนป้าย", "ขออนุญาตก่อนถอด/ปลดอุปกรณ์ความปลอดภัย", "ขออนุญาตก่อนเข้าที่อับอากาศ", "มีใบอนุญาตทำงานที่ได้รับอนุมัติ", "ไม่ดื่มแอลกอฮอล์/ไม่เสพสารเสพติด", "คาดเข็มขัดนิรภัยขณะขับขี่", "สวมหมวกนิรภัยขณะขับขี่จักรยานยนต์", "ไม่ใช้โทรศัพท์ขณะขับขี่"]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;
insert into settings(scg_company_id,key,value) values(null,'po_fields','[["po_no", "เลข PO", true], ["project", "โครงการ/หมู่บ้าน", true], ["contractor", "ผู้รับเหมา (รหัส Vendor / เลขภาษี / ชื่อ)", true], ["job_types", "ประเภทงาน (คั่นด้วย ,)", true], ["start_date", "วันเริ่ม", true], ["end_date", "วันจบ", false], ["start_time", "เวลานัด", false], ["house_no", "บ้านเลขที่/แปลง", false], ["address", "ที่อยู่", false], ["lat", "ละติจูด", false], ["lng", "ลองจิจูด", false], ["occupied", "มีผู้อยู่อาศัย (Y/N)", false]]'::jsonb) on conflict (scg_company_id,key) do update set value=excluded.value;

do $$ declare c uuid; g uuid; begin
  insert into scg_companies(name,short,color) values('SCG Distribution','SCGD','#1F5FAD') returning id into c;
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้งไม้พื้น',0) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ปูพื้นภายใน (ไม้/SPC/ลามิเนต)','{}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ไม้บันได/บัวพื้น','{}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้งแผ่นกันสาด (Shinkolite)',1) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'กันสาดติดผนัง','{wah,lifting}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'หลังคาโรงจอดรถ (โครงเหล็ก)','{wah,hot,lifting}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'เปลี่ยนแผ่นบนโครงเดิม','{wah}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'Shading/ระแนง','{wah,hot}','{}');
  insert into scg_companies(name,short,color) values('SCG Home Experience','SCGHE','#0B6B4A') returning id into c;
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้งรางน้ำ',0) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'รางน้ำใหม่','{wah}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'เปลี่ยนรางเดิม (รื้อ)','{wah}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ตะแกรงกันใบไม้/ท่อระบาย','{wah}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ฝ้าชายคา/เชิงชาย','{wah}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้งหลังคา',1) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'Roof Renovate','{wah,lifting}','{asbestos}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'หลังคาใหม่/Garage','{wah,hot,lifting}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ซ่อมรั่ว/เปลี่ยนกระเบื้อง','{wah}','{asbestos}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ฉนวน/AAQ','{wah,confined,electric}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้งประตู/รั้ว',2) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'มอเตอร์ประตูรั้ว/Door lock','{electric}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ประตูรั้ว (เชื่อม)','{hot,lifting}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานต่อเติมบ้าน',3) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'น็อคดาวน์/ห้องสำเร็จรูป','{wah,hot,lifting}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ทาสี/กันซึม/ห้องน้ำ','{chemical}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ปรับพื้นทรุด/ฐานราก','{excavation}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ต่อเติมครัว/ห้อง','{wah,hot,excavation,lifting}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานตกแต่งสวน',4) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'จัดสวน/ปลูกต้นไม้/หญ้า','{excavation}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ทางเดิน/บล็อกปูพื้น','{excavation}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้ง Solar',5) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ติดตั้งแผง + อินเวอร์เตอร์','{wah,electric,lifting}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ล้าง/บำรุงรักษาแผง','{wah,electric}','{}');
  insert into install_groups(scg_company_id,name,sort) values(c,'งานติดตั้งลิฟต์',6) returning id into g;
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'ลิฟต์บ้าน','{electric,lifting,wah}','{}');
  insert into job_types(scg_company_id,group_id,name,hazards,extra) values(c,g,'บำรุงรักษา/ซ่อมลิฟต์','{electric,wah}','{}');
end $$;

-- ผู้ดูแลระบบ (System owner): สร้างบริษัท SCG และเชิญ Safety Admin คนแรกของแต่ละบริษัท · ไม่เห็นข้อมูลงาน
insert into invites(email,full_name,role,is_owner,scg_company_ids) values('CHANGE_ME@scg.com','ผู้ดูแลระบบ','safety_admin',true,
  (select array_agg(id) from scg_companies)) on conflict (email) do nothing;

-- ผู้ใช้ที่เคยเข้าระบบรุ่นก่อน: สร้างโปรไฟล์ใหม่ตามคำเชิญ (ไม่มีคำเชิญ = รอสิทธิ์)
insert into profiles(id,email,full_name,role,scg_company_ids,contractor_id,is_owner)
select u.id,lower(u.email),i.full_name,coalesce(i.role,'pending'),coalesce(i.scg_company_ids,'{}'),i.contractor_id,coalesce(i.is_owner,false)
from auth.users u left join invites i on lower(i.email)=lower(u.email) on conflict (id) do nothing;
