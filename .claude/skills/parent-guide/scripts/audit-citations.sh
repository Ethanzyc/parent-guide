#!/usr/bin/env bash
# Citation auditor: mechanical check that every source claim in an advice text
# is backed by the corpus (skill knowledge core + knowledge/ reviews).
#
# Usage: audit-citations.sh [--corpus DIR]... FILE...
#        audit-citations.sh [--corpus DIR]... --anchor "file.md §N"
#   --corpus DIR   add a corpus directory (default: this skill's references/
#                  plus the repo's knowledge/ when reachable from this script)
#   --anchor SPEC  verify a §-anchor cited in output exists in the corpus
#                  (anchor self-check for the 依据随行 rule; no FILE needed)
# Exit codes: 0 = all citations reconcile / anchor found; 1 = dangling/unsourced/anchor missing.
#
# v1 scope (to be continuously refined): known-org table + generic org
# suffixes, file references, conservative medical-claim heuristics.
# Boundary: this checks source EXISTENCE (dangling orgs / files / bare
# claims), not whether a cited org actually said the specific sentence --
# semantic conformance stays with human review / LLM-judge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CORPUS_DIRS=("$SKILL_DIR/references")
REPO_KNOWLEDGE="$(cd "$SKILL_DIR/../.." && pwd)/knowledge"
[ -d "$REPO_KNOWLEDGE" ] && CORPUS_DIRS+=("$REPO_KNOWLEDGE")

FILES=()
ANCHOR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --corpus) shift; CORPUS_DIRS+=("$1") ;;
    --anchor) shift; ANCHOR="$1" ;;
    *) FILES+=("$1") ;;
  esac
  shift
done

REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
export AUDIT_CORPUS_DIRS="${CORPUS_DIRS[*]}"
export AUDIT_REPO_ROOT="$REPO_ROOT"

# --anchor mode: verify a cited "file §N" anchor exists (依据随行 self-check)
if [ -n "$ANCHOR" ]; then
  export AUDIT_ANCHOR="$ANCHOR"
  rc=0
  python3 - <<'PY' || rc=$?
import os, re, sys, glob

corpus_dirs = os.environ["AUDIT_CORPUS_DIRS"].split()
spec = os.environ["AUDIT_ANCHOR"]
m = re.match(r'\s*([A-Za-z0-9_\-\.]+)\s*(?:§\s*(\d+))?\s*$', spec)
if not m:
    print(f'FAIL: 无法解析锚点「{spec}」(期望形如「文件名 §数字」)')
    sys.exit(1)
fname, sec = m.group(1), m.group(2)
paths = [p for d in corpus_dirs
         for p in glob.glob(os.path.join(d, "**", fname), recursive=True)]
if not paths:
    print(f"FAIL: 语料中找不到文件 {fname}")
    sys.exit(1)
if sec is None:
    print(f"PASS: {fname} 存在(未指定节号)")
    sys.exit(0)
text = open(paths[0], encoding="utf-8").read()
pat = re.compile(rf'^#{{2,3}}\s*(?:§\s*)?{sec}(?=[\.\s、):：])', re.M)
if pat.search(text):
    print(f"PASS: {fname} §{sec} 存在({paths[0]})")
    sys.exit(0)
heads = [h for h in text.splitlines()
         if re.match(r'^#{2,3}\s*(?:§\s*)?\d', h)]
print(f"FAIL: {fname} 未找到 §{sec};该文件的数字节:")
for h in heads[:12]:
    print(f"  {h}")
sys.exit(1)
PY
  exit "$rc"
fi

[ "${#FILES[@]}" -gt 0 ] || { echo "usage: audit-citations.sh [--corpus DIR]... FILE... | --anchor SPEC" >&2; exit 1; }

python3 - "${FILES[@]}" <<'PY'
import os, re, sys, glob

corpus_dirs = os.environ["AUDIT_CORPUS_DIRS"].split()
repo_root = os.environ["AUDIT_REPO_ROOT"]
files = sys.argv[1:]

# ---- load corpus text ------------------------------------------------------
corpus_chunks = []
for d in corpus_dirs:
    for path in glob.glob(os.path.join(d, "**", "*.md"), recursive=True):
        try:
            corpus_chunks.append(open(path, encoding="utf-8").read())
        except OSError:
            pass
CORPUS = "\n".join(corpus_chunks)

# ---- citation extraction ---------------------------------------------------
KNOWN_ORGS = [
    "AAP", "AAPD", "AASM", "WHO", "CDC", "NIH",
    "中国居民膳食指南", "膳食指南", "sDOR", "Ellyn Satter",
    "HealthyChildren", "Learn the Signs",
]
# generic org shapes: anything claiming to be an institution
GENERIC_ORG = re.compile(r"[\u4e00-\u9fff]{0,8}(?:协会|学会|研究院|基金会|组织)|(?:Academy|Association|Institute|Society|Foundation|Organization)", re.I)
FILE_REF = re.compile(r"(?:knowledge|references)/[A-Za-z0-9_\-]+\.md")
TIER = re.compile(r"T[123]")

# conservative medical-claim heuristics: quantified dosing / urgent directives
MED_QUANT = re.compile(r"\d+(?:\.\d+)?\s*(?:克|毫克|mg|g|毫升|ml|国际单位|IU|小时|次|片|滴|℃|度)")
MED_DIRECTIVE = re.compile(r"立即就医|马上送医|必须|禁止|绝对不|应该立刻|不能吃任何")
# emergency instructions carry the T1 context by definition (core §1 protocol)
EMERGENCY = re.compile(r"海姆立克|拍背|压胸|心肺复苏| CPR |拨\s?120|拨打\s?120|急救")

findings = []

def split_sentences(text):
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        for s in re.split(r"(?<=[。;;!!?])", line):
            s = s.strip()
            if s:
                yield s

for path in files:
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        findings.append(("read-error", path, str(e)))
        continue
    sentences = list(split_sentences(text))
    # document-level fallback: tier/org declared anywhere covers detail sentences
    # (real advice style: header sentence carries the citation, bullets expand)
    doc_tier = bool(TIER.search(text)) or bool(EMERGENCY.search(text))
    doc_orgs = [o for o in KNOWN_ORGS if o in text]
    for i, sent in enumerate(sentences):
        # context window: tier/org markers legitimately cover adjacent sentences
        ctx = " ".join(sentences[max(0, i - 1): i + 2])
        has_tier = bool(TIER.search(ctx)) or bool(EMERGENCY.search(ctx)) or doc_tier
        orgs = [o for o in KNOWN_ORGS if o in ctx] or doc_orgs
        generic = GENERIC_ORG.findall(ctx)
        # known org must exist somewhere in corpus
        for org in orgs:
            if org not in CORPUS:
                findings.append(("悬空来源", sent, f"已知机构 {org} 未在语料中出现"))
        # generic org mention must exist verbatim in corpus
        for g in generic:
            g = g.strip()
            if len(g) >= 2 and g not in CORPUS:
                findings.append(("悬空来源", sent, f"声称的机构「{g}」未在语料中出现"))
        # file references must exist (and be part of the shipped set)
        for ref in FILE_REF.findall(sent):
            if not os.path.exists(os.path.join(repo_root, ref)):
                findings.append(("悬空引用", sent, f"文件 {ref} 不存在"))
        # medical claim with neither tier nor org in context -> unsourced
        if not has_tier and not orgs and not generic:
            if MED_QUANT.search(sent) or MED_DIRECTIVE.search(sent):
                findings.append(("无来源医学断言", sent, "含剂量/强制指令,且邻近无 T 级标注与来源机构"))

for kind, sent, why in findings:
    print(f"[{kind}] {why}\n    > {sent}")

if findings:
    print(f"FAIL: {len(findings)} 处引用未通过对账(悬空/无来源)")
    sys.exit(1)
print("PASS: 全部引用通过对账")
PY
