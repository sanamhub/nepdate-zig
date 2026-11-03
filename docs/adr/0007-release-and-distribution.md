# ADR-0007: release and distribution

- **Status:** accepted
- **Date:** 2026-11-04

## Context

Zig has no registry. Packages are tarballs or Git repositories with a content hash in the consumer's
`build.zig.zon`. A release still needs a verifiable archive, a hash a consumer can pin, and a way to
show the archive came from this repository's workflow.

## Decision

A `v*` tag runs the full gates, builds `nepdate-zig-<version>.tar.gz` with `git archive`, writes
`SHA256SUMS`, and computes the Zig package hash with `zig fetch` on the release URL. The archive,
the checksum file, the hash, and a `.dependency` snippet are attested with GitHub build provenance
and attached to the GitHub release. The release body repeats the `zig fetch --save` command and the
`build.zig.zon` entry with the hash.

There is no publish job. The GitHub release is the publication. `verify-published.yml` resolves the
latest release, runs the archive through `zig fetch` on Linux, macOS and Windows, and builds a sample
that imports both modules and checks a date and a patro event. The release workflow calls that
workflow after creating the release.

The `production` environment protects the release job and has a tag rule for `v*`. The hub branch
that adds this port stays unmerged until the 1.0.0 release.

## Consequences

A consumer can pin a hash that was computed by the same workflow that built the archive. There is no
registry account to configure and no pending publisher. The archive must contain `build.zig`,
`build.zig.zon`, `src`, `vendor`, `shared` and the licence files; `.gitattributes` marks the
development-only paths `export-ignore`.
