# Mutation testing

There is no mutation-testing tool for Zig at this version. PIT, Infection, Stryker and `mutmut` target
other languages; none reads Zig 0.17 source or a Zig test binary. A hand-written mutator would test
the mutator more than the library, so this repository has no mutation run and no threshold.

The gates that stand in for it are the compiler in Debug and ReleaseSafe, `zig fmt --check`, the
shared vector suites (every row, including `ERR` rows), the every-day property loop, the seeded
parser corpus and the coverage floor. The reasoning is in
[ADR-0009](../adr/0009-build-ci-and-fuzzing.md) and [ADR-0010](../adr/0010-parser-fuzzing.md).
