#!/usr/bin/env bash
# E2E แอป ↔ เซิร์ฟเวอร์จริง: เปิดเซิร์ฟเวอร์จำลองกับฐานข้อมูลเทสต์ชั่วคราว
# (ไม่แตะ server/prisma/dev.db) แล้วรัน test/contract ด้วย HttpAppApi จริง
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-3999}"
[ -d server/node_modules ] || npm --prefix server install

PORT="$PORT" npm --prefix server run start:test >/tmp/ndid-contract-server.log 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null; wait $SERVER_PID 2>/dev/null || true' EXIT

for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1 && break
  sleep 0.5
done
curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null || {
  echo "เซิร์ฟเวอร์ไม่ขึ้น ดู /tmp/ndid-contract-server.log" >&2
  exit 1
}

flutter test test/contract --dart-define=API_BASE_URL="http://127.0.0.1:$PORT" "$@"
