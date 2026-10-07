-- 7 ต.ค. 2569 · Induction เป็นเงื่อนไขก่อนอนุมัติช่าง (Backlog: "ต้องทำในรอบอัปเดตถัดไป" ข้อ 1)
-- 1) approval_missing: รายการคุณสมบัติที่ยังขาด (ตรวจตัวบุคคล + Induction ที่บริษัทนี้รับรองแล้วและยังไม่หมดอายุ)
-- 2) decide_worker: กด "อนุมัติ" ไม่ได้ถ้ายังขาดคุณสมบัติ
-- 3) run_daily('morning'): แจ้งผู้ดูแลบริษัทผู้รับเหมาเมื่อ Induction ของช่างใกล้หมดอายุ (30 วัน) / หมดอายุแล้ว
-- วิธีใช้: วางทั้งไฟล์ใน Supabase › SQL Editor แล้วกด Run · รันซ้ำได้ปลอดภัย · ไม่ลบหรือแก้ข้อมูลเดิม
-- หมายเหตุ: ช่างที่อนุมัติไปแล้วก่อนหน้านี้ ยังเป็น "อนุมัติ" ตามเดิม แต่หน้าเว็บจะขึ้น "ขาดคุณสมบัติ" ถ้ายังไม่มี Induction ที่รับรองแล้ว

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

revoke execute on function approval_missing(uuid,uuid,date) from public, anon, authenticated;

-- ตรวจผล: ควรเห็นชื่อฟังก์ชัน approval_missing 1 แถว
select proname from pg_proc where proname='approval_missing';
