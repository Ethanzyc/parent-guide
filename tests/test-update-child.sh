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

    def test_21_profile_placeholders_counted(self):
        c = self.child()
        c["profile"]["preferences"]["books"] = "绘本偏好"   # inject a placeholder
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertEqual(code, 0, msg)                       # placeholder != error
        self.assertIn("1 处模板占位值", msg)                  # but it is counted

    def test_22_set_profile_sleep_note(self):
        code, msg = run(self.tmp, "set-profile", "--field", "sleep.note",
                        "--value", "21:30 前入睡,午睡 1.5h")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["sleep"]["note"], "21:30 前入睡,午睡 1.5h")

    def test_23_add_reminder_and_hot_context_field(self):
        code, msg = run(self.tmp, "add-reminder", "--due", "12-15",
                        "--topic", "入园作息准备:开始渐进前移", "--source", "入园准备")
        self.assertEqual(code, 0, msg)
        r = self.child()["reminders"][-1]
        self.assertEqual(r["due"], "12-15")
        self.assertEqual(r["status"], "pending")
        # duplicate guard
        code, msg = run(self.tmp, "add-reminder", "--due", "12-15",
                        "--topic", "入园作息准备:开始渐进前移", "--source", "入园准备")
        self.assertNotEqual(code, 0)

    def test_24_reminder_status_transition(self):
        run(self.tmp, "add-reminder", "--due", "11-10", "--topic", "流感疫苗", "--source", "疫苗")
        code, msg = run(self.tmp, "set-reminder-status", "--due", "11-10",
                        "--topic", "流感疫苗", "--status", "done")
        self.assertEqual(code, 0, msg)
        r = [x for x in self.child()["reminders"] if x["due"] == "11-10"][0]
        self.assertEqual(r["status"], "done")

    def test_25_childcare_plan_in_set_profile(self):
        code, msg = run(self.tmp, "set-profile", "--field", "childcarePlan",
                        "--value", "计划36月入托,本地公办优先")
        self.assertEqual(code, 0, msg)
        self.assertIn("入托", self.child()["profile"]["childcarePlan"])

    def test_26_set_milestone_records_and_replaces(self):
        items = json.dumps([
            {"domain": "语言/沟通", "text": "会说两个词以上的句子", "status": "ok"},
            {"domain": "动作", "text": "单脚跳", "status": "todo"},
        ], ensure_ascii=False)
        code, msg = run(self.tmp, "set-milestone", "--months", "30", "--items", items,
                        "--source", "CDC 2.5岁检查表")
        self.assertEqual(code, 0, msg)
        pack = self.child()["milestones"]["30"]
        self.assertEqual(len(pack["items"]), 2)
        self.assertEqual(pack["source"], "CDC 2.5岁检查表")
        self.assertIn("assessed", pack)
        self.assertIn("已会 1", msg)
        # 重新盘点 = 整组覆盖,不追加
        code, msg = run(self.tmp, "set-milestone", "--months", "30", "--items", items)
        self.assertEqual(code, 0, msg)
        self.assertEqual(len(self.child()["milestones"]["30"]["items"]), 2)

    def test_27_set_milestone_fail_fast(self):
        code, msg = run(self.tmp, "set-milestone", "--months", "30", "--items", "not-json")
        self.assertNotEqual(code, 0)
        code, msg = run(self.tmp, "set-milestone", "--months", "30", "--items", "[]")
        self.assertNotEqual(code, 0)
        bad = json.dumps([{"domain": "x", "text": "y", "status": "great"}])
        code, msg = run(self.tmp, "set-milestone", "--months", "30", "--items", bad)
        self.assertNotEqual(code, 0)
        self.assertIn("ok/watch/todo", msg)
        miss = json.dumps([{"domain": "", "text": "y", "status": "ok"}])
        code, msg = run(self.tmp, "set-milestone", "--months", "30", "--items", miss)
        self.assertNotEqual(code, 0)

    def test_28_check_validates_milestone_assessed_date(self):
        c = self.child()
        c["milestones"] = {"30": {"source": "x", "assessed": "2026/10/01", "items": []}}
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertNotEqual(code, 0)
        self.assertIn("assessed", msg)

    def test_29_init_optional_gender_first_round(self):
        (self.tmp / "child.json").unlink()
        code, msg = run(self.tmp, "init", "--name", "小明", "--birthdate", "2023-06-15",
                        "--caregivers", "妈妈为主", "--gender", "女孩")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["profile"]["gender"], "女孩")
        # 省略 --gender:模板占位保留(=未填,check 计数不报错)
        (self.tmp / "child.json").unlink()
        code, msg = run(self.tmp, "init", "--name", "小明", "--birthdate", "2023-06-15",
                        "--caregivers", "妈妈为主")
        self.assertEqual(code, 0, msg)
        code2, msg2 = run(self.tmp, "check")
        self.assertEqual(code2, 0, msg2)

    def test_30_set_focus_replaces_whole_set(self):
        code, msg = run(self.tmp, "set-focus", "--items", "如厕训练,吃饭要喂")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["currentFocus"], ["如厕训练", "吃饭要喂"])
        self.assertIn("自主进食", msg)          # 划掉的旧项要在回执里可见
        # 清空也合法(战场全部解决)
        code, msg = run(self.tmp, "set-focus", "--items", "")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["currentFocus"], [])

    def test_31_set_concern_status_flow(self):
        code, msg = run(self.tmp, "set-concern-status",
                        "--text", "就餐时要求看动画片,不给则哭闹", "--status", "已解决")
        self.assertEqual(code, 0, msg)
        c = self.child()["activeConcerns"][0]
        self.assertEqual(c["status"], "已解决")
        c["status"] = "观察中"
        code, msg = run(self.tmp, "set-concern-status",
                        "--text", "不存在的问题", "--status", "已解决")
        self.assertNotEqual(code, 0)
        self.assertIn("现有", msg)

    def test_32_check_validates_concern_status(self):
        c = self.child()
        c["activeConcerns"] = [{"since": "09-05", "text": "x", "status": "好了"}]
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertNotEqual(code, 0)
        self.assertIn("activeConcerns", msg)

    def test_33_set_followup_status_retires(self):
        fu = self.child()["followups"][0]
        code, msg = run(self.tmp, "set-followup-status",
                        "--due", fu["due"], "--topic", fu["topic"], "--status", "done")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["followups"][0]["status"], "done")
        # done 项留档;双精确匹配防误伤:同 due 不同 topic 必须拒绝
        code, msg = run(self.tmp, "set-followup-status",
                        "--due", fu["due"], "--topic", "不存在的主题", "--status", "done")
        self.assertNotEqual(code, 0)
        self.assertIn("现有", msg)

    def test_34_check_validates_followup_status(self):
        c = self.child()
        c["followups"][0]["status"] = "完结"
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertNotEqual(code, 0)
        self.assertIn("followups", msg)

    def test_35_add_growth_records_and_replaces(self):
        code, msg = run(self.tmp, "add-growth", "--date", "2026-09-15",
                        "--height", "92.5", "--weight", "13.2")
        self.assertEqual(code, 0, msg)
        recs = self.child()["growth"]["records"]
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["height"], 92.5)
        self.assertEqual(recs[0]["weight"], 13.2)
        self.assertIsInstance(recs[0]["months"], int)   # 月龄自动换算入记录
        # 同日重录=替换(儿保抄录场景),不追加
        code, msg = run(self.tmp, "add-growth", "--date", "2026-09-15", "--height", "93")
        self.assertEqual(code, 0, msg)
        self.assertIn("替换", msg)
        recs = self.child()["growth"]["records"]
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["height"], 93.0)
        self.assertNotIn("weight", recs[0])             # 部分重录覆盖整条(显式语义)
        # 乱序日期落档后按日期排序
        code, _ = run(self.tmp, "add-growth", "--date", "2026-03-10", "--height", "85")
        self.assertEqual(code, 0)
        recs = self.child()["growth"]["records"]
        self.assertEqual([r["date"] for r in recs], ["2026-03-10", "2026-09-15"])

    def test_36_add_growth_validates_input(self):
        code, msg = run(self.tmp, "add-growth", "--date", "2026-09-15")
        self.assertNotEqual(code, 0)
        self.assertIn("at least one", msg)
        code, msg = run(self.tmp, "add-growth", "--date", "2026-09-15", "--height", "abc")
        self.assertNotEqual(code, 0)
        code, msg = run(self.tmp, "add-growth", "--date", "2026-09-15", "--height", "300")
        self.assertNotEqual(code, 0)
        self.assertIn("plausible", msg)

    def test_37_check_validates_growth_records(self):
        c = self.child()
        c["growth"] = {"records": [{"date": "26-09", "height": "很高"}]}
        raw = json.loads((self.tmp / "child.json").read_text("utf-8"))
        raw[next(k for k in raw if not k.startswith("_"))] = c
        (self.tmp / "child.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
        code, msg = run(self.tmp, "check")
        self.assertNotEqual(code, 0)
        self.assertIn("growth.records", msg)

    def test_38_short_date_fields_normalize_full_dates(self):
        # 2026-10-07 实测发现的缺陷:对话侧给 MM-DD 字段传 YYYY-MM-DD,
        # 写入器原样放行,要等 check 才拦住。写入即合规:完整日期自动去年份。
        code, msg = run(self.tmp, "add-strategy", "--name", "超市玩具规则",
                        "--applied", "预告+共情+零兑换", "--started", "2026-10-08")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["strategies"][-1]["started"], "10-08")
        code, msg = run(self.tmp, "add-followup", "--due", "2026-10-22",
                        "--topic", "规则回访")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["followups"][-1]["due"], "10-22")
        code, msg = run(self.tmp, "check")
        self.assertEqual(code, 0, msg)
        # 匹配型动作同样归一:set-followup-status 传完整日期也能命中
        code, msg = run(self.tmp, "set-followup-status", "--due", "2026-10-22",
                        "--topic", "规则回访", "--status", "done")
        self.assertEqual(code, 0, msg)
        # add-reminder 的 --due 同样归一
        code, msg = run(self.tmp, "add-reminder", "--due", "2026-11-02",
                        "--topic", "流感疫苗", "--source", "疫苗")
        self.assertEqual(code, 0, msg)
        self.assertEqual(self.child()["reminders"][-1]["due"], "11-02")

unittest.main(verbosity=2, argv=["test-update-child"])
PY
