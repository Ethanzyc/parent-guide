#!/usr/bin/env bash
# Structural assertions for the knowledge base (fail fast, repeatable).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K="$ROOT/knowledge"

for f in milestones.md sleep.md nutrition.md; do
  [ -f "$K/$f" ] || { echo "FAIL: knowledge/$f missing"; exit 1; }
done

M="$K/milestones.md"
# attribution + public-domain note
grep -q "CDC" "$M" && grep -q "公有领域" "$M" || { echo "FAIL: CDC attribution/public-domain note missing"; exit 1; }
# 11 fully-verified checkpoints + the 15-month explanatory stub
for age in "## 2 个月" "## 4 个月" "## 6 个月" "## 9 个月" "## 12 个月" "## 15 个月" "## 18 个月" "## 2 岁" "## 2 岁半" "## 3 岁" "## 4 岁" "## 5 岁"; do
  grep -q "^$age" "$M" || { echo "FAIL: section '$age' missing"; exit 1; }
done
# four domains per full section
DOMAIN_COUNT=$(grep -c "^\*\*社交/情感\|^\*\*语言/沟通\|^\*\*认知\|^\*\*动作/身体发育" "$M")
[ "$DOMAIN_COUNT" -ge 44 ] || { echo "FAIL: expected >=44 domain headings (11 sections x 4), got $DOMAIN_COUNT"; exit 1; }
# 15-month stub must be explicit about deferral (no invented items)
grep -q "M6.1" "$M" || { echo "FAIL: 15-month section must defer completion to M6.1"; exit 1; }
# generic act-early guidance present
grep -q "何时联系医生" "$M" || { echo "FAIL: act-early guidance missing"; exit 1; }

for f in sleep.md nutrition.md; do
  grep -q "自写综述" "$K/$f" || { echo "FAIL: $f must declare itself a self-written review"; exit 1; }
done

echo "PASS: knowledge base structure OK (milestones 11 verified sections + 15mo stub, sleep, nutrition)"
