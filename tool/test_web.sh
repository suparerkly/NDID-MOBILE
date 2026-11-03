#!/usr/bin/env bash
# Playwright E2E: build แอปเวอร์ชันเว็บให้ชี้ไปที่เซิร์ฟเวอร์เทสต์ แล้วรันเทสต์ใน Chromium
# Playwright เปิดเซิร์ฟเวอร์จำลองกับฐานข้อมูลชั่วคราว (ไม่แตะ dev.db) และเสิร์ฟ build/web เอง
# ภาพหน้าจอทุกขั้นอยู่ที่ e2e-web/test-results/artifacts/
# ใช้: ./tool/test_web.sh [อาร์กิวเมนต์ของ playwright test เช่น -g W1]
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d server/node_modules ] || npm --prefix server install
[ -d e2e-web/node_modules ] || npm --prefix e2e-web install

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  flutter build web --release --no-web-resources-cdn \
    --dart-define=API_BASE_URL=http://127.0.0.1:3998
fi

cd e2e-web
npx playwright test "$@"
