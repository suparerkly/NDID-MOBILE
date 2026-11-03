#!/usr/bin/env bash
# Run every test suite of NDID Verify LOSE and print a one-line summary per suite.
# Usage (from anywhere inside the repo): bash .claude/skills/ndid-testing/scripts/run_all.sh
# Full logs go to $LOG_DIR (default: a new temp dir), printed at the end.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
[ -x /opt/flutter/bin/flutter ] && export PATH=/opt/flutter/bin:$PATH
LOG_DIR="${LOG_DIR:-$(mktemp -d -t ndid-test-logs-XXXX)}"
status=0

summ_flutter() { # last reporter line looks like "00:14 +58 ~4: All tests passed!" or "+55 ~4 -3: Some tests failed."
  tail -c 400 "$1" | tr '\r' '\n' | grep -oE '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: (All tests passed!|Some tests failed\.)' | tail -1
}

if ! command -v flutter >/dev/null; then
  echo "flutter not found: install Flutter 3.24.5 (see SKILL.md)"; exit 1
fi
[ -d server/node_modules ] || npm --prefix server install --no-audit --no-fund >/dev/null

echo "== flutter analyze"
flutter analyze >"$LOG_DIR/analyze.log" 2>&1 || status=1
grep -E "No issues found|issues? found" "$LOG_DIR/analyze.log" | tail -1

echo "== flutter test (unit + widget + e2e; contract skipped)"
flutter test >"$LOG_DIR/flutter.log" 2>&1 || status=1
summ_flutter "$LOG_DIR/flutter.log"

echo "== contract (app <-> real server, temp DB)"
./tool/test_contract.sh >"$LOG_DIR/contract.log" 2>&1 || status=1
summ_flutter "$LOG_DIR/contract.log"

echo "== server API"
npm --prefix server test >"$LOG_DIR/server.log" 2>&1 || status=1
grep -E "^# (tests|pass|fail|duration_ms)" "$LOG_DIR/server.log" | tr '\n' ' '; echo

echo "== per-file test counts"
for f in test/unit/*.dart test/widget_test.dart test/e2e/*.dart test/contract/*.dart; do
  printf '%-45s %s\n' "$f" "$(grep -cE '^\s*(testWidgets|test)\(' "$f")"
done
echo "(server/test/api.test.js has loops; use the '# tests' number above)"

echo "== versions / commit"
flutter --version 2>/dev/null | head -1; node -v; git log --oneline -1; git branch --show-current
pubspec_dirty=$(git status --short pubspec.lock)
[ -n "$pubspec_dirty" ] && echo "WARNING: pubspec.lock changed. Wrong Flutter version? Restore with: git checkout pubspec.lock"

echo "logs: $LOG_DIR"
exit $status
