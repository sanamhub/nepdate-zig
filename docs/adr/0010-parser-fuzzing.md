# ADR-0010: parser fuzzing without `zig build test --fuzz`

- **Status:** accepted
- **Date:** 2026-11-04

## Context

Zig 0.17 has a built-in fuzzer behind `zig build test --fuzz`. The parsers in this package are in
the vendored C amalgamation. In fuzz mode the Zig compiler instruments the C objects for comparison
coverage, but the fuzz runtime that provides the counters is linked only for Zig code. The result is
either an undefined `__sanitizer_cov_trace_cmp*` symbol or, when the C comparison coverage is
disabled, a panic from the fuzzer's initialization because the C object has no pc counters. This is
a Zig and C interaction, not a parser failure.

## Decision

The CI does not run `zig build test --fuzz`. Instead the test suite contains a seeded parser corpus:
5000 inputs of random length and bytes, mixed with the parser alphabet and all 256 byte values, fed
to both parsers. A failure is a normal test failure with a reproducible seed. The seven-name
corpus from the shared parsing spec is also present as ordinary test cases.

The fuzz gap is recorded in `SECURITY.md` next to the missing CodeQL support. The gate that does run
is the seeded corpus, the 69 shared parse rows, the 42 C# golden strict rows, and the every-day
property loop.

## Consequences

The parser gets adversarial input in CI, but the built-in coverage-guided search is not available
until the fuzzer can instrument a mixed Zig and C test. The ADR is the explicit record; a future Zig
release that links the runtime for C objects can replace the seeded loop with `--fuzz`.
