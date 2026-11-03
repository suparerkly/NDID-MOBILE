#!/usr/bin/env bash
# E2E แอป ↔ เซิร์ฟเวอร์จริง: เปิดเซิร์ฟเวอร์จำลองกับฐานข้อมูลเทสต์ชั่วคราว
# (ไม่แตะ server/prisma/dev.db) แล้วรัน test/contract ด้วย HttpAppApi จริง
set -uo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-3999}"
LOG="${TMPDIR:-/tmp}/ndid-contract-server.log"
[ -d server/node_modules ] || npm --prefix server install

# ถ้ามีอะไรตอบที่พอร์ตนี้อยู่แล้ว เทสต์จะไปคุยกับเซิร์ฟเวอร์เก่าแทน จึงหยุดก่อน
if curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
  echo "พอร์ต $PORT มีเซิร์ฟเวอร์อื่นเปิดอยู่ ปิดก่อน หรือใช้ PORT=<พอร์ตอื่น> ./tool/test_contract.sh" >&2
  exit 1
fi

(cd server && PORT="$PORT" exec node scripts/with-test-db.js node src/server.js) >"$LOG" 2>&1 &
SERVER_PID=$!
stop_server() {
  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
}
trap stop_server EXIT

for _ in $(seq 1 60); do
  curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1 && break
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.5
done
if ! curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
  echo "เซิร์ฟเวอร์ไม่ขึ้น ดู $LOG" >&2
  exit 1
fi

flutter test test/contract --dart-define=API_BASE_URL="http://127.0.0.1:$PORT" "$@"
status=$?
exit $status
