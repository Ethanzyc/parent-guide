#!/usr/bin/env bash
# Create a writable run copy from fictional test fixtures. Fixtures are never touched.
# Usage: tests/run-test.sh <run-id>   e.g. red-20260928
set -euo pipefail

RUN_ID="${1:?usage: run-test.sh <run-id> e.g. red-20260928}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.test-runs/$RUN_ID"

if [ -e "$DEST" ]; then
  echo "refusing to overwrite existing run dir: $DEST" >&2
  exit 1
fi

mkdir -p "$DEST"
cp -R "$ROOT/tests/fixtures/test-env/data" "$DEST/data"

# fail fast: run copy must be valid JSON
python3 - "$DEST/data/child.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    json.load(f)
print("child.json: valid JSON")
PY

echo "run dir ready: $DEST"
