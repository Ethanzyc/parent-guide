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

# issues section (issue-tracking-v1 §4): id + pending-care + derived next followup
printf '%s\n' "$OUT" | grep -q "\[问题\]"   || { echo "FAIL: no issue section"; exit 1; }
printf '%s\n' "$OUT" | grep -q "P1"         || { echo "FAIL: no issue id"; exit 1; }
printf '%s\n' "$OUT" | grep -q "就医待办"   || { echo "FAIL: no pending-care line"; exit 1; }
printf '%s\n' "$OUT" | grep -q "下一回访"   || { echo "FAIL: no next-followup line"; exit 1; }

# patterns layer: one line when data/patterns.md exists, nothing when it doesn't
printf '%s\n' "$OUT" | grep -q "规律层:patterns.md" || { echo "FAIL: no patterns line with file present"; exit 1; }
BARE="$(mktemp -d)"
cp "$ROOT/tests/fixtures/test-env/data/child.json" "$BARE/"
BARE_OUT="$(bash "$ROOT/skills/parent-guide/scripts/hot-context.sh" "$BARE")"
if printf '%s\n' "$BARE_OUT" | grep -q "规律层"; then
  echo "FAIL: patterns line printed without file"; exit 1
fi
rm -rf "$BARE"

# profile staleness hint (2026-10-14): no _asOf (never migrated) -> silent;
# stale _asOf (>6 months) -> one nudge line naming the stale fields
if printf '%s\n' "$OUT" | grep -q "未核实"; then
  echo "FAIL: stale-profile line printed for fixture without _asOf"; exit 1
fi
STALE_DIR="$(mktemp -d)"
cp "$ROOT/tests/fixtures/test-env/data/child.json" "$STALE_DIR/"
python3 - "$STALE_DIR/child.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
k = next(x for x in d if not x.startswith("_"))
old = (d[k].get("profile", {}).get("_asOf") or {})
today = __import__("datetime").date.today().isoformat()
d[k]["profile"]["_asOf"] = {"temperament": "2026-01-01", "language": today,
                            "comfortObject": today, "caregivers": today,
                            "familyNotes": today, "allergies": today}
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False)
PY
STALE_OUT="$(bash "$ROOT/skills/parent-guide/scripts/hot-context.sh" "$STALE_DIR")"
printf '%s\n' "$STALE_OUT" | grep -q "画像:气质超 6 月未核实" \
  || { echo "FAIL: stale-profile nudge line missing"; exit 1; }
if printf '%s\n' "$STALE_OUT" | grep -q "语言超 6 月"; then
  echo "FAIL: fresh field must not be flagged"; exit 1
fi
rm -rf "$STALE_DIR"

echo "PASS: hot-context ($LINES lines)"
