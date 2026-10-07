#!/bin/sh
# คัดลอกหน้าเว็บ (root ของ repo) มาไว้ที่ www/ สำหรับทดสอบ · ใช้ config.test.js แทน config.js จริง
cd "$(dirname $0)"; mkdir -p www
for f in ../../*.js ../../*.css ../../*.html ../../*.webmanifest ../../*.png ../../*.svg ../../tools; do
  b=$(basename $f); [ "$b" = config.js ] || cp -r $f www/
done
cp config.test.js www/config.js
