# Competitors

The section 7 rule in the hub's benchmark protocol compares a port only with mature, used Bikram
Sambat libraries in its own ecosystem. Zig has no package registry and, at the date below, no such
library.

## Method

Searches on 2026-11-04:

- GitHub repository search for `nepali date language:Zig` and `bikram sambat language:Zig`;
- GitHub code search for `nepdate` written in Zig;
- the Zig package index and `ziggit` community lists, which are not registries and have no usage
  counts.

## Candidates

| Candidate | Source | First release | Last activity | License | Usage measure | Verdict |
|---|---|---|---|---|---|---|
| (none) | GitHub search returned no Zig library | - | - | - | no registry usage measure exists | no candidate |

No candidate passes the maturity bar because no candidate exists. The C core in `vendor/nepdate-c/`
is the reference this package wraps, not a competitor, and it is measured separately in
[benchmarks.md](benchmarks.md).

## Selection

No competitor row. The benchmark table has the Zig wrapper and the C core only, and the docs say
that this is a comparison with the wrapped implementation, not with an independent library. This is
the "no mature library to compare" case in section 7 of the protocol, not a list padded with a new or
obscure package.
