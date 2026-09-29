#!/usr/bin/env bash
# Unit test for hot-context.sh against fictional fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

OUT="$(bash "$ROOT/skills/parent-guide/scripts/hot-context.sh" "$ROOT/tests/fixtures/test-env/data")"

LINES="$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
[ "$LINES" -le 40 ] || { echo "FAIL: $LINES lines > 40"; exit 1; }

printf '%s\n' "$OUT" | grep -q "月龄"       || { echo "FAIL: no age line"; exit 1; }
printf '%s\n' "$OUT" | grep -q "S12"        || { echo "FAIL: no active strategy"; exit 1; }
printf '%s\n' "$OUT" | grep -q "10-03"      || { echo "FAIL: no followup date"; exit 1; }
printf '%s\n' "$OUT" | grep -q "戒奶嘴"      || { echo "FAIL: no suspended item"; exit 1; }
printf '%s\n' "$OUT" | grep -q "桃子"        || { echo "FAIL: no child name"; exit 1; }

echo "PASS: hot-context ($LINES lines)"
