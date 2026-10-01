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
  init          --name --birthdate --caregivers [--temperament] [--focus a,b]
                  create the archive skeleton (guided onboarding; refuses
                  to overwrite an existing real archive)
  add-strategy  --name --applied [--started MM-DD]   new strategy, auto id
  add-followup  --due MM-DD --topic                  append follow-up (dup-guarded)
  add-note      --date MM-DD --text                  append journal note
  mark-revisited --id --result [--status effective|partial|ineffective]
  set-status    --id --status active|suspended|absorbed|ineffective [--note]

Every action prints an evidence summary -- the agent quotes it as proof the
record was written (evidence before claims).

Structure-change SOP (child.json has four mirrors; keep them in sync):
  1. skills/parent-guide/data-templates/child.json  -- the template users copy
  2. skills/parent-guide/scripts/hot-context.sh     -- reader (contract in header)
  3. THIS FILE: STRUCT constants + _check rules      -- writer + validator
  4. web/src/components/cards/                      -- renderer (defensive reads,
     NO red light there -- eyeball after changes)
  Then run: bash tests/test-hot-context.sh && bash tests/test-update-child.sh
  (the red lights for renames/removals live in these two suites + the
  publish gate's `check` on fixtures).
"""
import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

# ═══ STRUCT: field-structure contract (single point of truth) ═══
# Change the structure here FIRST, then walk the SOP above. Enums below are
# shared by write actions and `check`, so they can never drift apart.
VALID_STATUS = {"active", "effective", "partial", "ineffective", "suspended", "absorbed"}
MILESTONE_STATUS = {"ok", "watch", "todo"}
NOTE_PRECISION = {"day", "week", "month"}
DATE_FULL = re.compile(r"^\d{4}-\d{2}-\d{2}$")   # birthdate
DATE_SHORT = re.compile(r"^\d{2}-\d{2}$")        # MM-DD everywhere else
# template placeholder values: "not filled yet" is guidance, not an error
PLACEHOLDERS = {"MM-DD", "YYYY-MM-DD", "HH:MM", "女|男",
                "effective|partial|ineffective", "孩子小名",
                "绘本偏好", "活动偏好", "气质特点一句话", "语言发展一句话",
                "家庭管教口径、长辈观点等背景"}
# ═══ end STRUCT ═══


def _today():
    return date.today().strftime("%m-%d")


def _days_ago(n):
    from datetime import timedelta
    return (date.today() - timedelta(days=n)).isoformat()


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
    p.add_argument("--date", default=None,
                   help="YYYY-MM-DD (preferred) or MM-DD (current year assumed)")
    p.add_argument("--approx-days", default=None,
                   help="fuzzy recollection: N days ago; precision auto-graded "
                        "(<=7 day, <=21 week, else month) -- never invent exactness")
    p.add_argument("--tags", default=None, help="comma-separated event tags")
    p.add_argument("--text", required=True)

    p = sub.add_parser("mark-revisited")
    p.add_argument("--id", required=True)
    p.add_argument("--result", required=True)
    p.add_argument("--status", default=None, choices=["effective", "partial", "ineffective"])

    p = sub.add_parser("add-reminder")
    p.add_argument("--due", required=True, help="MM-DD")
    p.add_argument("--topic", required=True)
    p.add_argument("--source", required=True, help="e.g. 疫苗/入园准备/自定义")

    p = sub.add_parser("set-reminder-status")
    p.add_argument("--due", required=True)
    p.add_argument("--topic", required=True)
    p.add_argument("--status", required=True, choices=["pending", "done", "skipped"])

    p = sub.add_parser("set-status")
    p.add_argument("--id", required=True)
    p.add_argument("--status", required=True, choices=sorted(VALID_STATUS))
    p.add_argument("--note", default=None)

    p = sub.add_parser("set-milestone", help="record an L3 assessment for one "
                      "month-age: whole-set replace (re-assessment overwrites)")
    p.add_argument("--months", required=True, type=int)
    p.add_argument("--items", required=True,
                   help='JSON array [{"domain","text","status":ok|watch|todo},...]')
    p.add_argument("--source", default=None, help="e.g. CDC X 岁检查表")

    sub.add_parser("check", help="validate the archive: required fields, date "
                  "formats (YYYY-MM-DD / MM-DD), status enums, numeric fields, "
                  "id uniqueness; human-readable problem list")

    p = sub.add_parser("init", help="create the archive skeleton via guided "
                  "onboarding; refuses to overwrite an existing real archive")
    p.add_argument("--name", required=True)
    p.add_argument("--birthdate", required=True)
    p.add_argument("--caregivers", required=True)
    p.add_argument("--temperament", default=None)
    p.add_argument("--focus", default=None, help="comma-separated currentFocus items")

    p = sub.add_parser("set-profile", help="update one whitelisted profile field "
                  "(guided onboarding follow-up; replaces manual JSON edits)")
    p.add_argument("--field", required=True,
                   choices=["gender", "language", "temperament", "comfortObject",
                            "familyNotes", "preferences.books", "preferences.activities",
                            "sleep.note", "childcarePlan"])
    p.add_argument("--value", required=True)

    args = ap.parse_args(argv)
    path = Path(args.data) / "child.json"
    template = Path(__file__).parent.parent / "data-templates" / "child.json"

    # init works on a missing file or an unfilled template; never on real data
    if args.action == "init":
        if not DATE_FULL.match(args.birthdate):
            return 1, "ERROR: --birthdate must be YYYY-MM-DD"
        existing = None
        if path.exists():
            try:
                _, _, existing = _load(path)
            except (OSError, ValueError, StopIteration):
                return 1, f"ERROR: {path} exists but is unreadable; fix or remove it first"
            if str(existing.get("name", "")) not in PLACEHOLDERS and str(existing.get("name", "")).strip():
                return 1, (f"ERROR: 档案已存在(孩子:{existing.get('name')}),init 拒绝覆盖;"
                           "如确要重建,请先手动删除/移走 child.json(备份在 .bak)")
        doc = json.loads(template.read_text("utf-8"))
        key = next(k for k in doc if not k.startswith("_"))
        child = doc[key]
        child["name"] = args.name
        child["birthdate"] = args.birthdate
        child["profile"]["caregivers"] = args.caregivers
        if args.temperament:
            child["profile"]["temperament"] = args.temperament
        child["currentFocus"] = [f.strip() for f in (args.focus or "").split(",") if f.strip()]
        # drop teaching samples from the template: a fresh archive starts empty
        for section in ("strategies", "suspended", "experiments", "followups", "notes",
                         "reminders"):
            child[section] = []
        child["activeConcerns"] = []
        child["milestones"] = {}
        child["sleep"] = {"days": [], "note": ""}
        problems, _ph = _check(child)
        if problems:
            return 1, "ERROR: init produced an invalid archive:\n" + "\n".join(problems)
        _save(path, doc)
        return 0, (f"recorded archive for {args.name}(birthday {args.birthdate}, "
                   f"caregivers: {args.caregivers}) | saved {path.name} (backup: child.json.bak) "
                   f"| 建议接着跑: hot-context 看一眼系统眼里的孩子")

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
        if (args.date is None) == (args.approx_days is None):
            return 1, "ERROR: give exactly one of --date or --approx-days"
        precision = "day"
        if args.date:
            if DATE_FULL.match(args.date):
                iso = args.date
            elif DATE_SHORT.match(args.date):
                iso = f"{date.today().year}-{args.date}"
            else:
                return 1, (f"ERROR: --date must be YYYY-MM-DD or MM-DD (got {args.date!r});"
                           " fuzzy recollections belong to --approx-days")
        else:
            try:
                back = int(args.approx_days)
                assert back >= 0
            except (ValueError, AssertionError):
                return 1, f"ERROR: --approx-days must be a non-negative integer (got {args.approx_days!r})"
            iso = _days_ago(back)
            precision = "day" if back <= 7 else ("week" if back <= 21 else "month")
        tags = [t.strip() for t in (args.tags or "").split(",") if t.strip()]
        child.setdefault("notes", []).append(
            {"date": iso, "precision": precision, "tags": tags, "text": args.text})
        prefix = iso if precision == "day" else f"≈{iso}"
        tagpart = f" [{'/'.join(tags)}]" if tags else ""
        msg = f"recorded note {prefix}({precision}){tagpart}: {args.text[:40]}"

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

    elif args.action == "set-profile":
        child.setdefault("profile", {}).setdefault("preferences", {})
        if args.field == "sleep.note":
            child.setdefault("sleep", {})["note"] = args.value
        elif args.field.startswith("preferences."):
            child["profile"]["preferences"][args.field.split(".", 1)[1]] = args.value
        else:
            child["profile"][args.field] = args.value
        msg = f"recorded {args.field} = {args.value[:40]}"

    elif args.action == "add-reminder":
        items = child.setdefault("reminders", [])
        if any(r.get("due") == args.due and r.get("topic") == args.topic for r in items):
            return 1, f"ERROR: reminder {args.due}「{args.topic}」already exists"
        items.append({"due": args.due, "topic": args.topic,
                      "source": args.source, "status": "pending"})
        msg = f"recorded reminder {args.due}「{args.topic}」({args.source})"

    elif args.action == "set-reminder-status":
        r = next((r for r in child.get("reminders", [])
                  if r.get("due") == args.due and r.get("topic") == args.topic), None)
        if r is None:
            return 1, f"ERROR: reminder {args.due}「{args.topic}」not found"
        r["status"] = args.status
        msg = f"reminder {args.due}「{args.topic}」-> {args.status}"

    elif args.action == "set-milestone":
        try:
            items = json.loads(args.items)
        except ValueError:
            return 1, "ERROR: --items must be a JSON array of {domain,text,status}"
        if not isinstance(items, list) or not items:
            return 1, "ERROR: --items must be a non-empty JSON array"
        clean = []
        for i, it in enumerate(items):
            if (not isinstance(it, dict) or not str(it.get("domain", "")).strip()
                    or not str(it.get("text", "")).strip()):
                return 1, f"ERROR: items[{i}] needs non-empty domain/text"
            if it.get("status") not in MILESTONE_STATUS:
                return 1, (f"ERROR: items[{i}].status must be one of "
                           f"{'/'.join(('ok', 'watch', 'todo'))} (got {it.get('status')!r})")
            clean.append({"domain": str(it["domain"]), "text": str(it["text"]),
                          "status": it["status"]})
        counts = {s: sum(1 for x in clean if x["status"] == s) for s in sorted(MILESTONE_STATUS)}
        child.setdefault("milestones", {})[str(args.months)] = {
            "source": args.source or "L3 盘点(CDC 检查表口径)",
            "assessed": _today(),
            "items": clean,
        }
        msg = (f"recorded milestone assessment {args.months}m: "
               f"已会 {counts['ok']} / 观察 {counts['watch']} / 未现 {counts['todo']}"
               f"(整组覆盖,重盘会替换该月龄整组)")

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
        nd = str(n.get("date") or "")
        if not (DATE_FULL.match(nd) or DATE_SHORT.match(nd)):
            problems.append(f"notes[{i}].date: 须为 YYYY-MM-DD(新)或 MM-DD(旧,视为当年;"
                            f"现在是 {nd!r})")
        prec = n.get("precision", "day")
        if prec not in NOTE_PRECISION:
            problems.append(f"notes[{i}].precision: 不在枚举 day/week/month(现在是 {prec!r})")
        tags = n.get("tags", [])
        if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
            problems.append(f"notes[{i}].tags: 须为字符串数组(现在是 {tags!r})")

    # profile free-text fields: placeholder originals count as "not filled yet"
    prof = child.get("profile", {})
    for f in ("gender", "language", "temperament", "comfortObject", "familyNotes"):
        is_ph(f"profile.{f}", prof.get(f))
    for f in ("books", "activities"):
        is_ph(f"profile.preferences.{f}", (prof.get("preferences") or {}).get(f))

    for i, d in enumerate(child.get("sleep", {}).get("days", [])):
        for field in ("wakings", "totalHours"):
            if not isinstance(d.get(field), (int, float)):
                problems.append(f"sleep.days[{i}].{field}: 须为数字(现在是 {d.get(field)!r})")

    REMINDER_STATUS = {"pending", "done", "skipped"}
    for i, r in enumerate(child.get("reminders", [])):
        short_date(f"reminders[{i}].due", r.get("due"))
        if r.get("status") not in REMINDER_STATUS:
            problems.append(f"reminders[{i}].status: 不在枚举 pending/done/skipped"
                            f"(现在是 {r.get('status')!r})")

    for months, pack in (child.get("milestones") or {}).items():
        for j, item in enumerate(pack.get("items", [])):
            if item.get("status") not in MILESTONE_STATUS:
                problems.append(f"milestones.{months}.items[{j}].status: 不在枚举 "
                                f"ok/watch/todo(现在是 {item.get('status')!r})")
        assessed = pack.get("assessed")
        if assessed and not (DATE_FULL.match(str(assessed)) or DATE_SHORT.match(str(assessed))):
            problems.append(f"milestones.{months}.assessed: 须为 YYYY-MM-DD 或 MM-DD"
                            f"(现在是 {assessed!r})")

    return problems, placeholders[0]


def main():
    code, msg = execute()
    print(msg)
    sys.exit(code)


if __name__ == "__main__":
    main()
