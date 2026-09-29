#!/usr/bin/env bash
# Assert the built bundle is a true single file: exists, and references no
# external scripts/styles (everything must be inlined by vite-plugin-singlefile).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$ROOT/web/dist/render.html"

[ -f "$BUNDLE" ] || { echo "FAIL: bundle missing: $BUNDLE"; exit 1; }

if grep -Eq '<script[^>]+src=' "$BUNDLE"; then
  echo "FAIL: external <script src=...> found"; grep -E '<script[^>]+src=' "$BUNDLE"; exit 1
fi
if grep -Eq '<link[^>]+rel="stylesheet"[^>]+href=' "$BUNDLE"; then
  echo "FAIL: external stylesheet link found"; exit 1
fi

SIZE="$(wc -c < "$BUNDLE" | tr -d ' ')"
echo "PASS: single-file bundle OK ($SIZE bytes): $BUNDLE"
