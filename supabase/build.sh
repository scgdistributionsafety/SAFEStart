#!/bin/sh
# รวมไฟล์ย่อยเป็น schema.sql ไฟล์เดียว
cd "$(dirname "$0")"
cat src/01_tables.sql src/02_rpc.sql src/03_ops.sql > schema.sql
python3 gen_seed.py
