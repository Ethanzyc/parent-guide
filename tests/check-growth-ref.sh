#!/usr/bin/env bash
# Growth md↔curve-card sync gate: knowledge/growth.md §4 full tables must equal
# web/src/lib/growth-ref.js (GROWTH_REF) value-for-value -- all 42 ages, both
# genders, both metrics, P3/P50/P97. Either side edited alone turns this red.
# (Verification levels differ by row -- see growth.md §4 note; this check only
# enforces that the two copies agree, not the provenance.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json, re, sys, pathlib

root = pathlib.Path(sys.argv[1])
js = (root / "web/src/lib/growth-ref.js").read_text(encoding="utf-8")
m = re.search(r"export const GROWTH_REF = (\{.*?\});\n", js, re.S)
if not m:
    sys.exit("FAIL: GROWTH_REF not found in growth-ref.js")
ref = json.loads(m.group(1))

md = (root / "knowledge/growth.md").read_text(encoding="utf-8")
sec = re.search(r"## 4\. 参考区间全表.*?(?=^## 5\.)", md, re.S | re.M)
if not sec:
    sys.exit("FAIL: knowledge/growth.md §4 全表 missing")
sec = sec.group(0)

ROW = r"^\| (\d+) \| ([\d.]+)-([\d.]+)-([\d.]+) \| ([\d.]+)-([\d.]+)-([\d.]+) \|$"
def parse_table(title):
    t = re.search(re.escape(title) + r"\n\n\| 月龄 \| 男童 \| 女童 \|\n\|---\|---\|---\|\n((?:\| .*\n)+)", sec)
    if not t:
        sys.exit(f"FAIL: §4 缺表「{title}」")
    return re.findall(ROW, t.group(1), re.M)

PCT = ("p3", "p50", "p97")
problems, seen = [], set()
for metric, title, rows in (("height", "**身高/身长(cm)**", None), ("weight", "**体重(kg)**", None)):
    rows = parse_table(title)
    for age_s, b3, b50, b97, g3, g50, g97 in rows:
        age = int(age_s)
        seen.add(age)
        for gender, vals in (("boys", (b3, b50, b97)), ("girls", (g3, g50, g97))):
            series = ref[gender][metric]
            if age not in series["ages"]:
                problems.append(f"{gender}/{metric} @{age}月: md 有而曲线卡无")
                continue
            i = series["ages"].index(age)
            for name, v in zip(PCT, vals):
                got = series[name][i]
                if abs(got - float(v)) > 1e-9:
                    problems.append(f"{gender}/{metric} @{age}月 {name}: md {v} vs 卡 {got}")

ref_ages = set(ref["boys"]["height"]["ages"])
if seen != ref_ages:
    problems.append(f"月龄集不一致: md 独有={sorted(seen - ref_ages)} 卡独有={sorted(ref_ages - seen)}")

if problems:
    print(f"FAIL: growth md↔曲线卡不同步({len(problems)} 处):")
    for p in problems[:10]:
        print("  -", p)
    sys.exit(1)
print(f"PASS: growth md↔曲线卡逐值同步({len(seen)} 月龄 × 2 性别 × 2 指标 × P3/P50/P97)")
PY
