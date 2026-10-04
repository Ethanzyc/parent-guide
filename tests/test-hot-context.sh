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
printf '%s\n' "$OUT" | grep -q "里程碑"      || { echo "FAIL: no milestone status line"; exit 1; }

# patterns layer: one line when data/patterns.md exists, nothing when it doesn't
printf '%s\n' "$OUT" | grep -q "规律层:patterns.md" || { echo "FAIL: no patterns line with file present"; exit 1; }
BARE="$(mktemp -d)"
cp "$ROOT/tests/fixtures/test-env/data/child.json" "$BARE/"
BARE_OUT="$(bash "$ROOT/skills/parent-guide/scripts/hot-context.sh" "$BARE")"
if printf '%s\n' "$BARE_OUT" | grep -q "规律层"; then
  echo "FAIL: patterns line printed without file"; exit 1
fi
rm -rf "$BARE"

echo "PASS: hot-context ($LINES lines)"
