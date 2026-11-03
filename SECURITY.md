# Security policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Report privately through
[GitHub security advisories](https://github.com/sanamhub/nepdate-zig/security/advisories/new).
Do not open a public issue.

Include the input that triggers it, the Zig version, the platform and the package version. Expect
a first reply within a week.

A wrong calendar result, where nepdate-zig and the shared data give the same wrong answer, belongs
to the hub: [sanamhub/nepdate security policy](https://github.com/sanamhub/nepdate/security/policy).

## Code scanning

The workflows are scanned with CodeQL. CodeQL does not support Zig, so the library code is not
scanned by it; this is a language limitation, not a missing job. The library has no package
dependency and compiles a vendored C amalgamation whose files are pinned by SHA-256. What stands in
for CodeQL is the compiler's safety checks in Debug and ReleaseSafe, `zig fmt --check`, the shared
test vectors, the seeded parser corpus and the coverage floor described in
[docs/adr/0006-tests-and-quality-gates.md](docs/adr/0006-tests-and-quality-gates.md). The built-in
Zig fuzzer cannot instrument the C amalgamation; [ADR-0010](docs/adr/0010-parser-fuzzing.md)
records that limitation.

The vendored C code is also compiled and tested by the C port's own CI at the tag recorded in
`vendor/nepdate-c/VENDORED_FROM`.
