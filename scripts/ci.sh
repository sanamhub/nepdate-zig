#!/usr/bin/env bash
# Every local gate, in the same order CI runs them. zsh is not required.
set -euo pipefail
cd "$(dirname "$0")/.."

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  PYTHON=python
fi

zig fmt --check build.zig test_root.zig src tests examples bench

"$PYTHON" tools/check_vendor.py
"$PYTHON" tools/generate_shared.py --check
"$PYTHON" tools/check_docs.py
"$PYTHON" tools/check_public_api.py
"$PYTHON" tools/release_check.py --draft --no-archive

zig build test
zig build docs-examples

if [[ "${1:-}" == "--coverage" ]]; then
  scripts/coverage.sh
fi
