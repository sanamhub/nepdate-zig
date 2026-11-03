# ADR-0006: tests and quality gates

- **Status:** accepted
- **Date:** 2026-11-04

## Context

The shared vectors are the contract between ports. Zig's compiler catches many memory and overflow
errors in Debug and ReleaseSafe, but it has no separate static analyzer or mutation tool. A gate
that only runs on Linux must be explicit rather than quietly skipped.

## Decision

`zig build test` runs the core tests, the patro tests and one integration suite that reads every
shared vector file through `@embedFile`. The suites assert every row, including the `ERR` rows and
the deliberate deviations for Devanagari digits, the month-abbreviation fix, and the data-end range
behaviour. The integration suite also walks all 109,212 supported days, round-trips each through
Gregorian and `YYYYMMDD`, and runs seeded property checks. A seeded parser corpus is part of the
suite; the built-in fuzzer cannot instrument the C amalgamation, and
[ADR-0010](0010-parser-fuzzing.md) records why.

`zig fmt --check` is the formatting gate. `zig build check` compiles the modules, tests and examples.
CI runs the tests in Debug and ReleaseSafe, cross-compiles six targets, checks the vendored C tag
and checks the generated constants. The coverage floor is 75 percent of the vendored C engine lines
and is enforced by kcov on Linux. The floor is in `scripts/coverage.sh`, not in a local command
line. kcov 43 cannot read the DWARF 5 line tables Zig emits, so the Zig wrapper is not in the
report; ADR-0009 records the scope.

## Consequences

The gates are reproducible with `scripts/ci.sh`. Coverage needs Linux and is CI-only; the local
run still executes every other gate. The 75 percent floor may move only with a recorded reason, not
by silently editing the script.
