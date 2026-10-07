#!/bin/sh
# ล้างฐานทดสอบแล้วติดตั้งใหม่ + ข้อมูลตัวอย่าง
P="psql -h /tmp -p 5433 -U postgres -q -v ON_ERROR_STOP=1"
$P -d postgres -c "drop database if exists ss with (force)" -c "create database ss" >/dev/null
$P -d ss -f "$(dirname $0)/stub.sql" 2>/dev/null
$P -d ss -f "$(dirname $0)/../supabase/schema.sql" 2>&1 | grep -v NOTICE
$P -d ss -f "$(dirname $0)/../supabase/seed.sql"
$P -d ss -f "$(dirname $0)/demo_seed.sql"
pkill -USR1 postgrest 2>/dev/null; true
