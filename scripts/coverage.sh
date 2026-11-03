#!/usr/bin/env bash
# Line coverage with kcov. Runs on Linux; Windows and macOS have no kcov.
# kcov 43 cannot read Zig's DWARF 5 line tables, so the gate covers the C engine
# the wrapper calls. ADR-0009 records the scope.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v kcov >/dev/null 2>&1; then
  echo "FAIL: kcov is not installed; the coverage gate runs in the Linux CI job" >&2
  exit 1
fi

zig build test-bin
rm -rf coverage
mkdir -p coverage
kcov \
  --include-pattern="$PWD/vendor/nepdate-c/" \
  "$PWD/coverage" \
  "$PWD/zig-out/bin/nepdate-tests"
report="$(find coverage -name coverage.json -print -quit)"
python3 tools/coverage_floor.py "$report" 75
