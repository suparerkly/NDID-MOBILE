#!/usr/bin/env bash
# Plant known bugs in lib/ one at a time, run the E2E suite, and report whether the tests catch each one.
# lib/ is restored with `git checkout lib` after every mutation, so it refuses to start
# if lib/ has uncommitted changes (they would be lost).
# Usage: bash .claude/skills/ndid-testing/scripts/mutation_check.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
[ -x /opt/flutter/bin/flutter ] && export PATH=/opt/flutter/bin:$PATH

if [ -n "$(git status --porcelain lib)" ]; then
  echo "lib/ has uncommitted changes; commit or stash them first."; exit 2
fi
trap 'git checkout -q lib' EXIT

# id @ file @ sed expression @ description
mutations=(
  "M1@lib/services/app_state.dart@s/policies.insert(0, policy);/policies.add(policy);/@new policy appended instead of first"
  "M2@lib/screens/purchase_screen.dart@s/if (!formValid || !_acceptedTerms) return;/if (!formValid) return;/@can pay without accepting terms"
  "M3@lib/screens/verification_result.dart@s/(_) => false,/(route) => route.isFirst,/@can navigate back after verification"
)

missed=0
for m in "${mutations[@]}"; do
  IFS='@' read -r id file expr desc <<<"$m"
  sed -i "$expr" "$file"
  if git diff --quiet -- "$file"; then
    echo "$id SKIPPED (pattern not found in $file; code changed?): $desc"; continue
  fi
  result=$(flutter test test/e2e 2>&1 | tail -c 400 | tr '\r' '\n' | grep -oE '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: (All tests passed!|Some tests failed\.)' | tail -1)
  git checkout -q lib
  if [[ "$result" == *"Some tests failed"* ]]; then
    echo "$id CAUGHT ($result): $desc"
  else
    echo "$id MISSED ($result): $desc"; missed=$((missed + 1))
  fi
done
exit $missed
