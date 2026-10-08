#!/usr/bin/env bash
# Structural assertions for the knowledge base (fail fast, repeatable).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K="$ROOT/knowledge"

for f in milestones.md sleep.md nutrition.md emotion.md activities.md tantrum-cdc.md anticipatory.md weaning.md toilet.md growth.md child-mind.md; do
  [ -f "$K/$f" ] || { echo "FAIL: knowledge/$f missing"; exit 1; }
done

# provenance trio (source + ingest date + verification method) in every knowledge file header
for f in milestones.md sleep.md nutrition.md emotion.md activities.md tantrum-cdc.md anticipatory.md weaning.md toilet.md growth.md child-mind.md; do
  head -12 "$K/$f" | grep -q "入库" || { echo "FAIL: $f header lacks ingest-date line (入库)"; exit 1; }
  head -12 "$K/$f" | grep -q "核对=" || { echo "FAIL: $f header lacks verification method (核对=)"; exit 1; }
done

# gap backlog: cross-conversation record that feeds batch corpus work
[ -f "$K/BACKLOG.md" ] || { echo "FAIL: knowledge/BACKLOG.md missing"; exit 1; }
grep -q "| 日期 |" "$K/BACKLOG.md" || { echo "FAIL: BACKLOG.md lacks table header"; exit 1; }

# closed set: knowledge root holds only official files; self-built goes to knowledge/user/
# (must stay in sync with the publish.sh whitelist)
for f in "$K"/*.md; do
  case "$(basename "$f")" in
    milestones.md|sleep.md|nutrition.md|emotion.md|activities.md|tantrum-cdc.md|anticipatory.md|weaning.md|toilet.md|growth.md|child-mind.md|README.md|LICENSE.md|BACKLOG.md) ;;
    *) echo "FAIL: unknown root knowledge file '$f' — official set is closed; register it in publish.sh+here, or move it to knowledge/user/ (self-built layer)"; exit 1 ;;
  esac
done
# self-built layer: convention doc exists (ships; content under user/ never does)
[ -f "$K/user/README.md" ] || { echo "FAIL: knowledge/user/README.md (self-built layer convention) missing"; exit 1; }

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

echo "PASS: knowledge base structure OK (milestones 11 verified sections + 15mo stub; sleep, nutrition, emotion, activities reviews)"
