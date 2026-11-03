# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/). The first release of this port is `1.0.0-rc.1`, on the
line the family releases together.

## [Unreleased]

### Added

- The `nepdate` Zig package: Bikram Sambat dates from 1901-01-01 to 2199-12-30 with conversion to
  and from Gregorian, the `YYYYMMDD` integer form, arithmetic with clamp and spill, the calendar
  breakdown between two dates, fiscal years and quarters, English and Nepali formatting with
  patterns, strict and lenient parsing, inclusive date ranges, ordered batch conversion, and
  `toJson` with `fromJson`.
- The `nepdate_patro` Zig package: tithi, public holidays and events for 2077-01-01 to 2084-08-20.
- Both modules in one package over the vendored C amalgamation, with hand-written `extern`
  declarations because Zig 0.17 removed `@cImport`.
- Tests for every shared vector file, the C# golden rows, property tests over every supported day,
  and a fuzzer corpus for both parsers.
- CI on Linux, macOS and Windows, a coverage floor, the hub's shared-check, Scorecard, dependency
  review, the release and verify-published workflows, and a benchmark of B1 to B8.
