# ADR-0001: repository, toolchain and shared data

- **Status:** accepted
- **Date:** 2026-11-04

## Context

A Zig package is a source tree with `build.zig` and `build.zig.zon`; there is no registry. The hub
publishes `data/` and `spec/` as the language-neutral source of truth, and every port vendors them
as `shared/` at a hub commit. The C port already has a released amalgamation that passes the same
vectors.

## Decision

The core and the patro live in one repository, `sanamhub/nepdate-zig`, and release together from
one tag. The package version is `1.0.0-rc.1`, the first release of this port. The hub line stays
`0.2` until the family releases 1.0; this port has no `sdks` entry, so the hub's check accepts the
later line.

The toolchain is Zig 0.17.0. `shared/` is copied from the hub with `tools/shared_sync.py`; it is
never edited here. `src/generated/shared_data.zig` records only the bounds and counts the Zig side
needs and is checked with `python tools/generate_shared.py --check`. The calendar and patro tables
themselves are compiled from the C amalgamation.

Distribution is a tagged source archive. A user runs `zig fetch --save` on the release URL and Zig
records the hash in their `build.zig.zon`. There is no package manager to publish to.

## Consequences

A shared data update is a `shared/` sync, a generator run, and a patch release. A change to the
calendar engine is a C port release, then a vendor update with new checksums. The repository is
buildable offline after the one-time toolchain download because it has no package dependency.
