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
    -- Induction (cert ที่ต้องมีทุกงาน) ของช่างที่อนุมัติแล้ว: ใกล้หมดอายุใน 30 วัน / หมดอายุแล้ว (ไม่นับถ้ามีใบใหม่มาแทน)
    for r in select x.contractor_id,
        string_agg(distinct case when x.expires_on>=d then x.full_name||' ('||x.cname||' หมด '||to_char(x.expires_on,'DD/MM/YYYY')||')' end,', ') soon,
        string_agg(distinct case when x.expires_on<d then x.full_name||' ('||x.cname||')' end,', ') gone
      from (select w.contractor_id, w.full_name, wc.expires_on, coalesce(setting(l.scg_company_id,'cert_types')->>wc.cert_type,wc.cert_type) cname
        from worker_links l join workers w on w.id=l.worker_id and w.active
        join worker_certs wc on wc.worker_id=w.id
        join cert_reviews cr on cr.cert_id=wc.id and cr.scg_company_id=l.scg_company_id and cr.status='approved'
        where l.status='approved' and wc.expires_on between d-7 and d+30
          and wc.cert_type in (select jsonb_array_elements_text(coalesce(setting(l.scg_company_id,'hazard_certs')->'all','[]')))
          and not exists(select 1 from worker_certs n where n.worker_id=wc.worker_id and n.cert_type=wc.cert_type and n.id<>wc.id and (n.expires_on is null or n.expires_on>wc.expires_on))) x
      where not exists(select 1 from notifications z where z.kind='cert_due' and z.created_at>now()-interval '7 days' and z.to_id=any(contractor_admins(x.contractor_id)))
      group by x.contractor_id loop
      perform notify_many(contractor_admins(r.contractor_id),null,'cert_due',
        case when r.gone is not null then 'ช่างขาดคุณสมบัติ: Induction หมดอายุ' else 'Induction ของช่างใกล้หมดอายุ (ภายใน 30 วัน)' end,
        concat_ws(' · ',case when r.gone is not null then 'หมดอายุแล้ว (เข้างานไม่ได้): '||r.gone end,case when r.soon is not null then 'ใกล้หมด: '||r.soon end)||' · อบรมใหม่แล้วเพิ่ม cert ใบใหม่ในแอป',
        'contractors',r.contractor_id,false,r.gone is not null);
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
revoke execute on function approval_missing(uuid,uuid,date) from public, anon, authenticated;
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
