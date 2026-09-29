#!/usr/bin/env python3
"""Deterministic writer for child.json (closed-loop record keeping).

Writing the archive by free-form language is the weakest link observed in
GREEN retest runs: content was legal but id assignment and field style
drifted across conversations. This script makes every mutation
deterministic: id continuation, field normalization, validation,
atomic write with one-generation backup, and duplicate guards.

Usage (run from anywhere; paths parameterized):
  update-child.py [--data DIR] <action> [options]
Actions:
  add-strategy  --name --applied [--started MM-DD]   new strategy, auto id
  add-followup  --due MM-DD --topic                  append follow-up (dup-guarded)
  add-note      --date MM-DD --text                  append journal note
  mark-revisited --id --result [--status effective|partial|ineffective]
  set-status    --id --status active|suspended|absorbed|ineffective [--note]

Every action prints an evidence summary -- the agent quotes it as proof the
record was written (evidence before claims).
"""
import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

VALID_STATUS = {"active", "effective", "partial", "ineffective", "suspended", "absorbed"}


def _today():
    return date.today().strftime("%m-%d")


def _load(path):
    doc = json.loads(path.read_text("utf-8"))
    key = next(k for k in doc if not k.startswith("_"))
    return doc, key, doc[key]


def _save(path, doc):
    """Atomic write with one-generation backup (bak replaced each save)."""
    backup = path.with_suffix(".json.bak")
    if path.exists():
        backup.write_text(path.read_text("utf-8"), encoding="utf-8")
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _next_strategy_id(child):
    nums = [int(m.group(1)) for s in child.get("strategies", [])
            for m in [re.match(r"S(\d+)$", str(s.get("id", "")))] if m]
    return f"S{max(nums, default=0) + 1}"


def _bump_evidence(evidence):
    m = re.search(r"回访 ×(\d+)", evidence or "")
    n = int(m.group(1)) + 1 if m else 1
    return f"回访 ×{n}"


def execute(argv=None):
    ap = argparse.ArgumentParser(prog="update-child.py")
    ap.add_argument("--data", default="./data", help="data directory (default ./data)")
    sub = ap.add_subparsers(dest="action", required=True)

    p = sub.add_parser("add-strategy")
    p.add_argument("--name", required=True)
    p.add_argument("--applied", required=True)
    p.add_argument("--started", default=None)

    p = sub.add_parser("add-followup")
    p.add_argument("--due", required=True)
    p.add_argument("--topic", required=True)

    p = sub.add_parser("add-note")
    p.add_argument("--date", default=None)
    p.add_argument("--text", required=True)

    p = sub.add_parser("mark-revisited")
    p.add_argument("--id", required=True)
    p.add_argument("--result", required=True)
    p.add_argument("--status", default=None, choices=["effective", "partial", "ineffective"])

    p = sub.add_parser("set-status")
    p.add_argument("--id", required=True)
    p.add_argument("--status", required=True, choices=sorted(VALID_STATUS))
    p.add_argument("--note", default=None)

    sub.add_parser("check", help="validate the archive: required fields, date "
                  "formats (YYYY-MM-DD / MM-DD), status enums, numeric fields, "
                  "id uniqueness; human-readable problem list")

    args = ap.parse_args(argv)
    path = Path(args.data) / "child.json"
    try:
        doc, key, child = _load(path)
    except (OSError, ValueError, StopIteration) as e:
        return 1, f"ERROR: cannot load {path}: {e}"

    if args.action == "add-strategy":
        sid = _next_strategy_id(child)
        child.setdefault("strategies", []).append({
            "id": sid, "name": args.name, "applied": args.applied,
            "started": args.started or _today(), "followup": "",
            "evidence": "回访 ×0", "status": "active",
        })
        msg = f"recorded strategy {sid}「{args.name}」(started {args.started or _today()}, status active)"

    elif args.action == "add-followup":
        items = child.setdefault("followups", [])
        if any(f.get("due") == args.due and f.get("topic") == args.topic for f in items):
            return 1, f"ERROR: followup {args.due}「{args.topic}」already exists (idempotency guard)"
        items.append({"due": args.due, "topic": args.topic, "status": "pending"})
        msg = f"recorded followup {args.due}「{args.topic}」"

    elif args.action == "add-note":
        child.setdefault("notes", []).append(
            {"date": args.date or _today(), "text": args.text})
        msg = f"recorded note {args.date or _today()}: {args.text[:40]}"

    elif args.action == "mark-revisited":
        s = next((s for s in child.get("strategies", []) if s.get("id") == args.id), None)
        if s is None:
            return 1, f"ERROR: strategy {args.id} not found"
        s["followup"] = args.result
        s["evidence"] = _bump_evidence(s.get("evidence", ""))
        if args.status:
            s["status"] = args.status
        msg = f"revisited {args.id}: {args.result[:40]} (now {s['evidence']}, status {s['status']})"

    elif args.action == "set-status":
        s = next((s for s in child.get("strategies", []) if s.get("id") == args.id), None)
        if s is None:
            return 1, f"ERROR: strategy {args.id} not found"
        s["status"] = args.status
        if args.note:
            s["followup"] = f"{s.get('followup', '')} {args.note}".strip()
        msg = f"strategy {args.id} status -> {args.status}" + (f" ({args.note})" if args.note else "")

    elif args.action == "check":
        problems, ph = _check(child)
        note = f"\n  提示: 还有 {ph} 处模板占位值待替换为真实内容" if ph else ""
        if problems:
            return 1, (f"FAIL: 档案有 {len(problems)} 处问题\n"
                       + "\n".join(f"  - {p}" for p in problems) + note)
        return 0, f"PASS: 档案结构合规(孩子:{child.get('name', '?')})" + note

    else:  # pragma: no cover
        return 1, "ERROR: unknown action"

    _save(path, doc)
    return 0, msg + f" | saved {path.name} (backup: child.json.bak)"


DATE_FULL = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DATE_SHORT = re.compile(r"^\d{2}-\d{2}$")
MILESTONE_STATUS = {"ok", "watch", "todo"}
# template placeholder values: "not filled yet" is guidance, not an error
PLACEHOLDERS = {"MM-DD", "YYYY-MM-DD", "HH:MM", "女|男",
                "effective|partial|ineffective", "孩子小名"}


def _check(child):
    """Validate one child dict; returns (problems, placeholder_count)."""
    problems = []
    placeholders = [0]

    def is_ph(where, value):
        if str(value) in PLACEHOLDERS:
            placeholders[0] += 1
            return True
        return False

    if not str(child.get("name") or "").strip():
        problems.append("name: 必填(孩子小名)")
    else:
        is_ph("name", child.get("name"))
    if not DATE_FULL.match(str(child.get("birthdate") or "")):
        if not is_ph("birthdate", child.get("birthdate")):
            problems.append("birthdate: 必须是 YYYY-MM-DD 格式(现在是 "
                            f"{child.get('birthdate')!r})")

    def short_date(where, value):
        if not DATE_SHORT.match(str(value or "")):
            if not is_ph(where, value):
                problems.append(f"{where}: 日期须为 MM-DD(现在是 {value!r})")

    for i, x in enumerate(child.get("activeConcerns", [])):
        short_date(f"activeConcerns[{i}].since", x.get("since"))
    for i, s in enumerate(child.get("strategies", [])):
        short_date(f"strategies[{i}].started", s.get("started"))
        if s.get("status") not in VALID_STATUS and not is_ph(f"strategies[{i}].status", s.get("status")):
            problems.append(f"strategies[{i}].status: 不在枚举内(现在是 {s.get('status')!r},"
                            f"可选 {'/'.join(sorted(VALID_STATUS))})")
        if not re.match(r"^[SM]\d+$", str(s.get("id") or "")):
            problems.append(f"strategies[{i}].id: 须形如 S1/M12(现在是 {s.get('id')!r})")
    ids = [s.get("id") for s in child.get("strategies", []) if s.get("id")]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        problems.append(f"strategies[].id: 重复 {sorted(dup)}")
    for i, s in enumerate(child.get("suspended", [])):
        short_date(f"suspended[{i}].since", s.get("since"))
    for i, e in enumerate(child.get("experiments", [])):
        short_date(f"experiments[{i}].since", e.get("since"))
    for i, f in enumerate(child.get("followups", [])):
        short_date(f"followups[{i}].due", f.get("due"))
    for i, n in enumerate(child.get("notes", [])):
        short_date(f"notes[{i}].date", n.get("date"))

    for i, d in enumerate(child.get("sleep", {}).get("days", [])):
        for field in ("wakings", "totalHours"):
            if not isinstance(d.get(field), (int, float)):
                problems.append(f"sleep.days[{i}].{field}: 须为数字(现在是 {d.get(field)!r})")

    for months, pack in (child.get("milestones") or {}).items():
        for j, item in enumerate(pack.get("items", [])):
            if item.get("status") not in MILESTONE_STATUS:
                problems.append(f"milestones.{months}.items[{j}].status: 不在枚举 "
                                f"ok/watch/todo(现在是 {item.get('status')!r})")

    return problems, placeholders[0]


def main():
    code, msg = execute()
    print(msg)
    sys.exit(code)


if __name__ == "__main__":
    main()
