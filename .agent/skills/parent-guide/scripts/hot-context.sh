#!/usr/bin/env bash
# Aggregate hot context from child.json (~30 lines, for the L1 fast path).
# Usage: hot-context.sh [data_dir]   (default: ./data)
# Contract: child.json field structure is this script's contract --
# renaming fields requires updating this script (and vice versa).
set -euo pipefail
DATA_DIR="${1:-./data}"
exec python3 - "$DATA_DIR/child.json" <<'PY'
import json, sys
from datetime import date

with open(sys.argv[1], encoding="utf-8") as f:
    doc = json.load(f)
key = next(k for k in doc if not k.startswith("_"))
c = doc[key]

today = date.today()
b = date.fromisoformat(c["birthdate"])
months = (today.year - b.year) * 12 + (today.month - b.month) - (today.day < b.day)
season = ["冬", "冬", "春", "春", "春", "夏", "夏", "夏", "秋", "秋", "秋", "冬"][today.month - 1]

p = c.get("profile", {})
ph = {"安抚物(如有)", "孩子小名", "主要照顾人与分工"}
caregivers = p.get("caregivers", "-")
comfort = p.get("comfortObject", "-")
if caregivers in ph or not str(caregivers).strip():
    caregivers = "未填"
if comfort in ph or not str(comfort).strip():
    comfort = "未填"
print(f"== {c['name']} 热区 | {today} ==")
print(f"月龄:{months} 个月(生日 {c['birthdate']})| 今日季节:{season}")
print(f"照顾:{caregivers} | 安抚物:{comfort}")
print(f"当前重点:{'、'.join(c.get('currentFocus', []))}")
print()
print("[活跃问题]")
for x in c.get("activeConcerns", []):
    print(f"- ({x['since']}) {x['text']} —— {x['status']}")
print()
print("[活跃策略]")
for s in c.get("strategies", []):
    print(f"- {s['id']} {s['name']}:{s['applied']}")
    print(f"  回访:{s['followup']} [{s['status']}]")
print()
print("[挂起]")
for s in c.get("suspended", []):
    print(f"- ({s['since']}) {s['topic']} —— {s['status']}")
print()
print("[试验]")
for e in c.get("experiments", []):
    print(f"- ({e['since']}) {e['name']}:{e['detail']}")
print()
print("[待回访]")
for fu in c.get("followups", []):
    print(f"- {fu['due']} {fu['topic']} [{fu['status']}]")
print()
print("[近期事件]")
for n in c.get("notes", [])[-3:]:
    d = str(n.get("date", ""))
    shown = d if n.get("precision", "day") == "day" else f"≈{d}"
    tags = n.get("tags") or []
    tagpart = f" [{'/'.join(tags)}]" if tags else ""
    print(f"- ({shown}){tagpart} {n['text']}")
PY
