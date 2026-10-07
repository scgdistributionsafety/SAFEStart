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
