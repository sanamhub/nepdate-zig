# ADR-0008: benchmarks and competitors

- **Status:** accepted
- **Date:** 2026-11-04

## Context

The benchmark protocol compares every port on the same 64 inputs, B1 to B8, and asks each port to
compare the most-used mature libraries in its ecosystem. Zig has no Bikram Sambat library and no
package registry with usage data. The port's own engine is the C amalgamation.

## Decision

The competitor is the C core that this package wraps, measured from the same executable and the
same 64 inputs. The harness has a Zig path and a direct C path for every operation. This is not a
competitor in the package-registry sense; it is the reference implementation, and the docs say so.
No library is invented or downloaded to make a table look better.

The machine was idle for 30 seconds with total CPU at 8.17 percent before the committed run, and the
command and affinity are recorded with the table. B5 formats into caller buffers on both sides, so
the comparison is the formatting work rather than an allocator difference; the docs state it.

## Consequences

The table shows the wrapper cost, not a contest between two independent libraries. A regression in
the wrapper is visible on B1, B2 and B7. There is no third-party agreement column because there is
no third-party candidate.
