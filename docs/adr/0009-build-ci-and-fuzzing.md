# ADR-0009: build, CI and the unavailable tools

- **Status:** accepted
- **Date:** 2026-11-04

## Context

Zig 0.17.0 is new enough that several marketplace setup actions do not carry it. CodeQL does not
support Zig, and Zig has no mutation-testing tool. The C amalgamation needs a C compiler and libc,
including on Windows.

## Decision

CI downloads Zig 0.17.0 from `ziglang.org` with a pinned SHA-256 in `scripts/install-zig.sh`. This
removes a third-party action from the trust path and works the same on three operating systems.
Every action that remains is pinned by commit SHA.

There is no `codeql.yml` and no `mutation.yml`. CodeQL has no Zig front end, and there is no mutation
tool for Zig; `SECURITY.md` says what stands in for both. The gates that do exist are the compiler
in Debug and ReleaseSafe, `zig fmt --check`, the shared vector suites, the seeded parser corpus and
the kcov coverage floor on Linux. The coverage is measured over the vendored C engine because
kcov 43 cannot read Zig's DWARF 5 line tables; the Zig wrapper is a thin checked layer over those
calls. A workflow that silently skipped a gate would be worse than an explicit absence.

Every workflow with shell blocks sets `defaults: run: shell: bash`, including the Windows jobs.
The release job installs Zig itself and runs the same `scripts/ci.sh` as pull requests, so the tag
does not use a tool the pull request never used.

## Consequences

The first CI run has no cache and downloads about 100 MB of Zig per job. In exchange, the toolchain
is exactly the pinned release and no setup action can lag behind. The Linux-only gates are named in
the docs and in the job names.
