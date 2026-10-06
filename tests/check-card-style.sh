#!/usr/bin/env bash
# Card-style gate: mechanically enforce the A·graph-paper design system
# (design-system.json) on web/src/components/cards/*.vue so new/edited cards
# cannot drift. Rules are deliberately mechanical (project rule: structure to
# scripts, semantics to humans):
#   1. <style> colors: hex only #fff/#ffffff (everything else via CSS vars);
#      rgba only white/graph-blue families
#   2. card-header <h3> lines must not contain emoji
#   3. border-radius values <= 12px (no pill capsules; graph-paper is square)
#   4. no linear-gradient (graph paper is flat)
# Run: bash tests/check-card-style.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CARDS="$ROOT/web/src/components/cards"

python3 - "$CARDS" <<'PY'
import re, sys, pathlib, unicodedata

cards = sorted(pathlib.Path(sys.argv[1]).glob("*.vue"))
assert cards, "no card components found"
problems = []

EMOJI_RANGES = ((0x1F300, 0x1FAFF), (0x2600, 0x27BF), (0x2B00, 0x2BFF))
HEX_ALLOW = {"#fff", "#ffffff"}
RGBA_ALLOW = re.compile(r"rgba\(\s*(255\s*,\s*255\s*,\s*255|90\s*,\s*130\s*,\s*180)\b")

def has_emoji(s):
    return any(any(lo <= ord(c) <= hi for lo, hi in EMOJI_RANGES) for c in s)

for p in cards:
    text = p.read_text(encoding="utf-8")
    # isolate the <style scoped> block (template colors are data, not styling)
    m = re.search(r"<style[^>]*>(.*?)</style>", text, re.S)
    style = m.group(1) if m else ""
    for hexv in re.findall(r"#[0-9a-fA-F]{3,8}\b", style):
        if hexv.lower() not in HEX_ALLOW:
            problems.append(f"{p.name}: style 裸 hex {hexv} -- 用 CSS 变量(白名单仅 #fff)")
    for rgba in re.findall(r"rgba?\([^)]*\)", style):
        if rgba.startswith("rgb(") or not RGBA_ALLOW.search(rgba):
            problems.append(f"{p.name}: style 非白名单 rgba {rgba} -- 仅 255,255,255 / 90,130,180 系")
    for br in re.findall(r"border-radius:\s*([\d.]+)px", style):
        if float(br) > 12:
            problems.append(f"{p.name}: border-radius {br}px > 12(图纸风=方角,禁胶囊)")
    if "linear-gradient" in style:
        problems.append(f"{p.name}: linear-gradient 禁用(图纸风=平面)")
    # card headers: <h3> opening lines carry no emoji
    for line in text.splitlines():
        if "<h3" in line and has_emoji(line):
            problems.append(f"{p.name}: 卡头含 emoji -- {line.strip()[:50]}")

if problems:
    print("FAIL: 卡片风格门禁发现问题:")
    for x in problems:
        print("  -", x)
    sys.exit(1)
print(f"PASS: card style OK ({len(cards)} cards, graph-paper rules held)")
PY
