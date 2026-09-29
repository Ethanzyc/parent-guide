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
    return uc.execute(["--data", str(data_dir), *args])

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

unittest.main(verbosity=2, argv=["test-update-child"])
PY
