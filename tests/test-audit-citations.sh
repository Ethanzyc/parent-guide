#!/usr/bin/env bash
# TDD test for audit-citations.sh against citation fixtures.
#   good.txt      -> exit 0, PASS
#   dangling.txt  -> exit 1, reports dangling org + missing file ref
#   unsourced.txt -> exit 1, reports unsourced medical claims
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/skills/parent-guide/scripts/audit-citations.sh"
CORPUS="--corpus $ROOT/skills/parent-guide/references --corpus $ROOT/knowledge"

if bash "$AUDIT" $CORPUS "$ROOT/tests/fixtures/citations/good.txt" > /tmp/audit-good.log 2>&1; then
  grep -q "PASS" /tmp/audit-good.log || { echo "FAIL: good case exit 0 but no PASS"; exit 1; }
  echo "PASS: good.txt (exit 0)"
else
  echo "FAIL: good.txt should pass"; cat /tmp/audit-good.log; exit 1
fi

if bash "$AUDIT" $CORPUS "$ROOT/tests/fixtures/citations/dangling.txt" > /tmp/audit-dangling.log 2>&1; then
  echo "FAIL: dangling.txt should fail"; exit 1
else
  grep -q "悬空" /tmp/audit-dangling.log || { echo "FAIL: dangling org not reported"; cat /tmp/audit-dangling.log; exit 1; }
  grep -q "不存在" /tmp/audit-dangling.log || { echo "FAIL: missing file ref not reported"; cat /tmp/audit-dangling.log; exit 1; }
  echo "PASS: dangling.txt (exit 1, both issues reported)"
fi

if bash "$AUDIT" $CORPUS "$ROOT/tests/fixtures/citations/unsourced.txt" > /tmp/audit-unsourced.log 2>&1; then
  echo "FAIL: unsourced.txt should fail"; exit 1
else
  COUNT=$(grep -c "无来源" /tmp/audit-unsourced.log || true)
  [ "$COUNT" -ge 3 ] || { echo "FAIL: expected >=3 unsourced reports, got $COUNT"; cat /tmp/audit-unsourced.log; exit 1; }
  echo "PASS: unsourced.txt (exit 1, $COUNT claims reported)"
fi

echo "PASS: audit-citations (all three fixture classes)"
