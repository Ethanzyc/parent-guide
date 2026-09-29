#!/usr/bin/env bash
# Unit tests for update-child.py: id continuation, normalization, atomic
# write with backup, idempotency guard, revisit counting.
# Run: bash tests/test-update-child.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, shutil, sys, tempfile, unittest
from pathlib import Path

ROOT = Path(sys.argv[1])
import importlib.util
_spec = importlib.util.spec_from_file_location(
    "update_child", ROOT / "skills/parent-guide/scripts/update-child.py")
uc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(uc)

FIXTURE = ROOT / "tests/fixtures/test-env/data/child.json"

def run(data_dir, *args):
    try:
        return uc.execute(["--data", str(data_dir), *args])
    except SystemExit as e:
        return (int(e.code) if isinstance(e.code, int) else 1, "(rejected: field not whitelisted)")

class T(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="pg-uc-test-"))
        shutil.copy(FIXTURE, self.tmp / "child.json")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def child(self):
        d = json.loads((self.tmp / "child.json").read_text("utf-8"))
        return d[next(k for k in d if not k.startswith("_"))]

    def test_01_id_sequence(self):
        code, msg = run(self.tmp, "add-strategy", "--name", "游戏化收玩具",
                        "--applied", "分类筐+送玩具回家")
        self.assertEqual(code, 0, msg)
        ids = [s["id"] for s in self.child()["strategies"]]
        self.assertIn("S13", ids)
        s = next(s for s in self.child()["strategies"] if s["id"] == "S13")
        self.assertEqual(s["status"], "active")
        self.assertIn("回访 ×0", s["evidence"])
        self.assertTrue(msg.strip())

    def test_02_atomic_write_with_backup(self):
        run(self.tmp, "add-note", "--date", "09-29", "--text", "第一次自己扣上纽扣")
        self.assertTrue((self.tmp / "child.json.bak").exists())
        json.loads((self.tmp / "child.json").read_text("utf-8"))
        self.assertFalse(list(self.tmp.glob("*.tmp")))

    def test_03_duplicate_followup_rejected(self):
        code, _ = run(self.tmp, "add-followup", "--due", "10-15", "--topic", "收玩具回访")
        self.assertEqual(code, 0)
        code, _ = run(self.tmp, "add-followup", "--due", "10-15", "--topic", "收玩具回访")
        self.assertNotEqual(code, 0)
        count = sum(1 for f in self.child()["followups"] if f["due"] == "10-15")
        self.assertEqual(count, 1)

    def test_04_revisit_updates_strategy(self):
        code, msg = run(self.tmp, "mark-revisited", "--id", "S12", "--result",
                        "09-29 回访:预告撤除后稳定", "--status", "effective")
        self.assertEqual(code, 0, msg)
        s = next(s for s in self.child()["strategies"] if s["id"] == "S12")
        self.assertIn("09-29 回访", s["followup"])
        self.assertEqual(s["status"], "effective")
        self.assertIn("回访 ×2", s["evidence"])

    def test_05_unknown_id_fails(self):
        code, _ = run(self.tmp, "mark-revisited", "--id", "S99", "--result", "x")
        self.assertNotEqual(code, 0)

    def test_06_absorption_status(self):
        code, msg = run(self.tmp, "set-status", "--id", "S12", "--status", "absorbed",
                        "--note", "被零屏幕计划吸收 09-29")
        self.assertEqual(code, 0, msg)
        s = next(s for s in self.child()["strategies"] if s["id"] == "S12")
        self.assertEqual(s["status"], "absorbed")
        self.assertIn("吸收", s["followup"])

    def test_07_broken_json_rejected(self):
        (self.tmp / "child.json").write_text("{broken", encoding="utf-8")
        code, _ = run(self.tmp, "add-note", "--date", "09-29", "--text", "x")
        self.assertNotEqual(code, 0)

    def test_08_check_passes_on_valid_fixture(self):
        code, msg = run(self.tmp, "check")
        self.assertEqual(code, 0, msg)
        self.assertIn("PASS", msg)

    def test_09_check_reports_each_violation(self):
        c = self.child()
        c["name"] = ""                       # required empty
        c["birthdate"] = "2024/4/10"         # wrong date format
        c["strategies"][0]["status"] = "有效"  # off-enum
        c["strategies"][1]["id"] = "M1"      # duplicate id
        c["strategies"][1]["started"] = "9月8日"  # wrong MM-DD
        c["sleep"] = {"days": [{"date": "09-22", "bedtime": "21:35", "wakings": "两次", "totalHours": 10.2}]}
        c.setdefault("milestones", {})["30"] = {"source": "x", "items": [{"domain": "认知", "status": "良好", "text": "t"}]}
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False, indent=2), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertNotEqual(code, 0)
        for kw in ["name", "birthdate", "status", "重复", "started", "wakings", "milestones"]:
            self.assertIn(kw, msg, f"missing report for {kw}")

    def test_10_init_creates_clean_skeleton(self):
        (self.tmp / "child.json").unlink()   # fresh user, no archive yet
        code, msg = run(self.tmp, "init", "--name", "小明", "--birthdate", "2023-06-15",
                        "--caregivers", "妈妈为主", "--focus", "如厕,睡眠")
        self.assertEqual(code, 0, msg)
        c = self.child()
        self.assertEqual(c["name"], "小明")
        self.assertEqual(c["birthdate"], "2023-06-15")
        self.assertEqual(c["profile"]["caregivers"], "妈妈为主")
        self.assertEqual(c["currentFocus"], ["如厕", "睡眠"])
        for empty in ("strategies", "followups", "notes", "suspended", "experiments"):
            self.assertEqual(c[empty], [], f"{empty} must start empty, not carry template samples")
        self.assertEqual(c["milestones"], {})
        self.assertEqual(c["sleep"]["days"], [])
        code2, msg2 = run(self.tmp, "check")
        self.assertEqual(code2, 0, msg2)

    def test_11_init_refuses_existing_real_archive(self):
        before = (self.tmp / "child.json").read_text("utf-8")
        code, msg = run(self.tmp, "init", "--name", "别人", "--birthdate", "2020-01-01",
                        "--caregivers", "x")
        self.assertNotEqual(code, 0, "must refuse to overwrite a real archive")
        self.assertIn("已存在", msg)
        self.assertEqual((self.tmp / "child.json").read_text("utf-8"), before, "file untouched")

    def test_12_init_allows_placeholder_template_state(self):
        # replace current fixture archive with the unfilled template -> init must proceed
        shutil.copy(ROOT / "skills/parent-guide/data-templates/child.json",
                    self.tmp / "child.json")
        code, msg = run(self.tmp, "init", "--name", "朵朵", "--birthdate", "2024-01-20",
                        "--caregivers", "父母")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["name"], "朵朵")

    def test_13_init_on_missing_file(self):
        (self.tmp / "child.json").unlink()
        code, msg = run(self.tmp, "init", "--name", "新新", "--birthdate", "2025-12-01",
                        "--caregivers", "妈妈")
        self.assertEqual(code, 0, msg)

    def test_14_set_profile_updates_whitelisted_field(self):
        code, msg = run(self.tmp, "set-profile", "--field", "comfortObject",
                        "--value", "奶嘴")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["profile"]["comfortObject"], "奶嘴")
        code, msg = run(self.tmp, "set-profile", "--field", "preferences.books",
                        "--value", "小金鱼逃走了")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["profile"]["preferences"]["books"], "小金鱼逃走了")

    def test_15_set_profile_rejects_unknown_field(self):
        code, msg = run(self.tmp, "set-profile", "--field", "name", "--value", "X")
        self.assertNotEqual(code, 0, "name is not a profile field; must be rejected")
        code, msg = run(self.tmp, "set-profile", "--field", "evil.path", "--value", "X")
        self.assertNotEqual(code, 0)

    def test_16_add_note_with_tags_and_full_date(self):
        code, msg = run(self.tmp, "add-note", "--date", "2026-08-01",
                        "--tags", "社交,分享", "--text", "主动拿车换警车")
        self.assertEqual(code, 0, msg)
        n = self.child()["notes"][-1]
        self.assertEqual(n["date"], "2026-08-01")
        self.assertEqual(n["precision"], "day")
        self.assertEqual(n["tags"], ["社交", "分享"])

    def test_17_add_note_short_date_gets_current_year(self):
        code, msg = run(self.tmp, "add-note", "--date", "09-29", "--text", "x")
        self.assertEqual(code, 0, msg)
        n = self.child()["notes"][-1]
        self.assertRegex(n["date"], r"^\d{4}-09-29$")

    def test_18_add_note_approx_days(self):
        code, msg = run(self.tmp, "add-note", "--approx-days", "35",
                        "--tags", "社交", "--text", "大概一个月前开始愿意分享")
        self.assertEqual(code, 0, msg)
        n = self.child()["notes"][-1]
        self.assertRegex(n["date"], r"^\d{4}-\d{2}-\d{2}$")
        self.assertEqual(n["precision"], "month")
        code, msg = run(self.tmp, "add-note", "--approx-days", "10",
                        "--text", "一周多前")
        n = self.child()["notes"][-1]
        self.assertEqual(n["precision"], "week")
        self.assertIn("≈", msg)   # evidence marks the fuzzy date

    def test_19_add_note_rejects_bad_date_format_on_write(self):
        code, msg = run(self.tmp, "add-note", "--date", "2026/9/1", "--text", "x")
        self.assertNotEqual(code, 0, "fail fast: bad format must be rejected at write time")
        code, msg = run(self.tmp, "add-note", "--approx-days", "abc", "--text", "x")
        self.assertNotEqual(code, 0)

    def test_20_check_validates_new_note_fields(self):
        c = self.child()
        c["notes"] = [{"date": "08-01", "precision": "month", "tags": "社交", "text": "x"}]
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertNotEqual(code, 0)
        self.assertIn("tags", msg)

unittest.main(verbosity=2, argv=["test-update-child"])
PY
