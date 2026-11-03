# Architecture decisions

| ADR | Decision |
|---|---|
| [0001](0001-repository-toolchain-and-shared-data.md) | One repository, Zig 0.17.0, the vendored shared data and the source archive distribution |
| [0002](0002-c-amalgamation-and-bindings.md) | The core and patro are compiled from the pinned C amalgamation, with hand-written `extern` declarations |
| [0003](0003-dates-arithmetic-and-errors.md) | Dates are four-byte values, arithmetic is whole months and days, and failures are error unions |
| [0004](0004-formatting-parsing-and-clocks.md) | Formatting takes allocators or buffers, parsing has two closed grammars, and clocks are injected |
| [0005](0005-patro-as-a-second-module.md) | The patro is the second module of the same package and owns the event allocations it returns |
| [0006](0006-tests-and-quality-gates.md) | Shared vectors, every-day round trips, Debug and ReleaseSafe, a coverage floor and parser fuzzing |
| [0007](0007-release-and-distribution.md) | One tag, one source archive, a recorded Zig hash, build provenance and no registry |
| [0008](0008-benchmarks-and-competitors.md) | B1 to B8 against the C core, with no separate Zig competitor |
| [0009](0009-build-ci-and-fuzzing.md) | Plain GitHub runners, no Zig setup action, the C tag check and the Linux-only gates |
| [0010](0010-parser-fuzzing.md) | The built-in fuzzer cannot instrument the C amalgamation; a seeded parser corpus stands in |
