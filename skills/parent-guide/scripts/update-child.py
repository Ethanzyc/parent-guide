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

    else:  # pragma: no cover
        return 1, "ERROR: unknown action"

    _save(path, doc)
    return 0, msg + f" | saved {path.name} (backup: child.json.bak)"


def main():
    code, msg = execute()
    print(msg)
    sys.exit(code)


if __name__ == "__main__":
    main()
