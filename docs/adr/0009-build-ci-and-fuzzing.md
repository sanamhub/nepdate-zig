# ADR-0009: build, CI and the unavailable tools

- **Status:** accepted
- **Date:** 2026-11-04

## Context

Zig 0.17.0 is new enough that several marketplace setup actions do not carry it. CodeQL does not
support Zig, and Zig has no mutation-testing tool. The C amalgamation needs a C compiler and libc,
including on Windows.

The coverage gate has a second problem. kcov instruments the test binary and reads its DWARF line
tables to attribute executed addresses to source lines. Zig 0.17 writes DWARF 5, and the line-table
header carries LLVM's `DW_LNCT_LLVM_source` entry, content type `0x2001`. kcov 43 reads the C and
test compilation units and silently skips every Zig module, so a gate aimed at `src/` would report
zero files rather than a real number.

## Decision

CI downloads Zig 0.17.0 from `ziglang.org` with a pinned SHA-256 in `scripts/install-zig.sh`. This
removes a third-party action from the trust path and works the same on three operating systems.
Every action that remains is pinned by commit SHA.

There is no `codeql.yml` and no `mutation.yml`. CodeQL has no Zig front end, and there is no mutation
tool for Zig; `SECURITY.md` says what stands in for both. The gates that do exist are the compiler
in Debug and ReleaseSafe, `zig fmt --check`, the shared vector suites, the seeded parser corpus, the
kcov floor on the vendored C engine and a public-API call check on the Zig sources.

The line-coverage number stays on the C engine, at 75 percent. In the final run it is 1,225 of
1,455 lines, 84.19 percent. The Zig wrapper is covered by `tools/check_public_api.py`, which lists
every `pub fn` in `src/` and fails if no test in `tests/`, `examples/` or a `test` block calls it.
That is a weaker statement than a line percentage, but it is true and reproducible.

### Coverage attempts, in the order tried

1. **DWARF 4 from the Zig build.** Zig 0.17 exposes `dwarf_format` on a module, but its type is
   `std.dwarf.Format = enum { @"32", @"64" }`: it selects 32-bit or 64-bit DWARF, not the version.
   `zig build-exe --help` has no `-gdwarf-4`, `-fdebug-version` or equivalent, and the test binary
   reports `Version: 5` under `readelf --debug-dump=info`. There is no supported way to ask this
   compiler for DWARF 4.

2. **A newer kcov.** kcov 43 is the latest stable release (2024-07-23). The v44 tags in the
   repository are pre-test tags, and the master `dwarf.cc` still parses CUs with
   `dwarf_nextcu`/`dwarf_getsrclines`; nothing in it addresses the LLVM content type. On the Linux
   test binary, kcov 43 with `--include-pattern=$PWD/src/` produced a `coverage.json` with zero
   files, and a run with no include filter still listed only the two C files. `addr2line` and
   `llvm-symbolizer-18` on the same binary report `DWARF error: unknown format content type 8193`,
   so this is a reader problem shared by the binutils, elfutils and LLVM 18 families, not a kcov
   version problem.

3. **Another line-coverage tool.** Zig has no source-based coverage instrumentation:
   `-fprofile-instr-generate` and `-fcoverage-mapping` are unrecognized parameters, so `llvm-cov`
   has no profile to read. Valgrind's callgrind ran the full suite (4.49 billion instructions) but
   attributed line records to the C files and the test files only; the imported Zig modules appear
   as call targets without line costs, and callgrind's source annotation cannot use them. No tool
   tested here gives a line percentage for `src/` that is worth gating.

The C gate and the public-API check are therefore the two coverage gates. A workflow that silently
skipped a gate would be worse than an explicit absence, so the limitation is named in the README and
here rather than hidden behind a number that only covers C.

Every workflow with shell blocks sets `defaults: run: shell: bash`, including the Windows jobs.
The release job installs Zig itself and runs the same `scripts/ci.sh` as pull requests, so the tag
does not use a tool the pull request never used.

## Consequences

The first CI run has no cache and downloads about 100 MB of Zig per job. In exchange, the toolchain
is exactly the pinned release and no setup action can lag behind. The Linux-only gates are named in
the docs and in the job names. The public-API check is static and cheap; it will not catch a public
function that is called with the wrong arguments, which the compiler and the vector tests already
cover.
