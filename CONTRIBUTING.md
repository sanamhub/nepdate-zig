# Contributing

Bug reports, fixes and documentation improvements are welcome. For a new feature or an API change,
open an issue first so the design can be agreed before you write code.

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems as
described in [SECURITY.md](SECURITY.md), not in a public issue.

## Scope

The shared calendar and patro data, the spec and the golden vectors live in the hub
([`sanamhub/nepdate`](https://github.com/sanamhub/nepdate)) and are copied into `shared/`
read-only. A wrong date, holiday or tithi is a data issue: report it in the hub, not here.

## Setup

You need Zig 0.17.0. The repository has no package dependency; the core and the patro are two
modules of one package and compile the vendored C amalgamation directly.

```sh
zig build test
zig build docs-examples
scripts/ci.sh
```

`scripts/ci.sh` runs the formatting check, the vendor check, the shared-data generator check, the
documentation check, the tests and the documentation examples
([ADR-0006](docs/adr/0006-tests-and-quality-gates.md) lists the gates).

The C source under `vendor/nepdate-c/` is never edited here. Change it in
[`sanamhub/nepdate-c`](https://github.com/sanamhub/nepdate-c), cut a release, then vendor the new
tag and its checksums. `src/generated/shared_data.zig` is generated from `shared/data`; run
`python tools/generate_shared.py` after a shared sync.

## Pull requests

- Keep a pull request to one change.
- Add or update a test for any behaviour change. The shared vector suites must keep passing.
- A public API change goes in `docs/API.md` in the same commit, with an example that runs.
- Add a line to the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md) for anything a user would
  notice.
- A significant design decision gets an ADR in `docs/adr/`. Accepted ADRs are not edited; a later
  ADR supersedes an earlier one.
- CI must pass.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, imperative,
lower case, no trailing period. Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`,
`ci`, `perf`. The body says why, not what.
