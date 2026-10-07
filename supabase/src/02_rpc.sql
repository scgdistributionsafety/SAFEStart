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

-- คุณสมบัติที่ต้องครบก่อนอนุมัติช่าง (คืนรายการที่ขาด) · cert ที่ต้องมีทุกงาน (hazard_certs.all = Induction) ต้องรับรองโดยบริษัทนี้และยังไม่หมดอายุ
create or replace function approval_missing(p_worker uuid, p_co uuid, p_on date default null) returns text[] language plpgsql stable security definer set search_path=public as $$
declare w workers; out text[] := '{}'; c text; names jsonb := setting(p_co,'cert_types'); d date := coalesce(p_on,bkk_today());
begin
  select * into w from workers where id=p_worker;
  if not found then return array['ไม่พบช่าง']; end if;
  if w.id_verified_at is null then out:=out||'ยังไม่ตรวจตัวบุคคล'::text; end if;
  if coalesce((setting(p_co,'rules')->>'enforce_certs')::boolean,true) then
    for c in select jsonb_array_elements_text(coalesce(setting(p_co,'hazard_certs')->'all','[]')) loop
      if not exists(select 1 from worker_certs wc join cert_reviews r on r.cert_id=wc.id and r.scg_company_id=p_co and r.status='approved'
         where wc.worker_id=p_worker and wc.cert_type=c and (wc.expires_on is null or wc.expires_on>=d)) then
        out:=out||('ขาด '||coalesce(names->>c,c)||' ที่รับรองแล้วและยังไม่หมดอายุ');
      end if;
    end loop;
  end if;
  return out;
end $$;

create or replace function decide_worker(p_co uuid, p_worker uuid, p_approve boolean, p_note text) returns void language plpgsql security definer set search_path=public as $$
declare w workers; miss text[];
begin
  perform need(role_in(p_co,array['purchasing','installation_consultant','safety_admin']),'ไม่มีสิทธิ์อนุมัติช่าง');
  select * into w from workers where id=p_worker;
  perform need(exists(select 1 from worker_links where worker_id=p_worker and scg_company_id=p_co),'ช่างคนนี้ยังไม่ได้ขอเข้าทำงานกับบริษัทนี้');
  if p_approve then perform need(w.id_verified_at is not null,'ต้องตรวจตัวบุคคลก่อนอนุมัติ');
    miss := approval_missing(p_worker,p_co);
    perform need(cardinality(miss)=0,'ยังอนุมัติไม่ได้ · '||array_to_string(miss,' · '));
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
