# ADR-0002: the C amalgamation and hand-written bindings

- **Status:** accepted
- **Date:** 2026-11-04

## Context

Zig 0.17 removed `@cImport`, and `translate-c` is deprecated in favour of an external package. The
public C API is small and stable. Reimplementing the calendar in Zig would create a second engine to
keep in step with the C port, and the C port already passes every shared vector.

## Decision

`vendor/nepdate-c/` holds `nepdate.c`, `nepdate.h`, `nepdate_patro.c` and `nepdate_patro.h` copied
from `sanamhub/nepdate-c` at tag `v0.2.0-rc.1`, commit
`77af203878acf290f5024b249e8b31b67a38dc69`. `SHA256SUMS` pins every file and `VENDORED_FROM` records
the tag and commit. `tools/check_vendor.py` verifies the local files; CI also downloads the tag and
compares the bytes.

`src/c.zig` and `src/patro_c.zig` are hand-written `extern` declarations for the public C API. The
two files are deliberate: the core module and the patro module must not share a source file, because
a Zig file belongs to one module. They duplicate a few four-byte struct declarations, which is
checked by the tests that pass dates between them.

The Zig API is built on top: `Date` wraps the C value, `Range` wraps two dates, error statuses map to
one Zig error set, and strings are built into caller buffers or allocator-owned sentinel slices.

## Consequences

The Zig package has no C dependency at install time; it compiles the amalgamation in its own build.
A C port fix reaches Zig through a new tag and a vendor update, never through an edit here. The
wrapper can only expose what the C API offers, which is why the couple of C# conveniences that need
objects or `TimeSpan` are absent.
