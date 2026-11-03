# ADR-0004: formatting, parsing and clocks

- **Status:** accepted
- **Date:** 2026-11-04

## Context

Every port must expose the same text forms: short, long, patterns, English and Nepali. Zig has no
built-in formatter for this calendar, and the C core already implements the pattern language,
including the trailing-backslash and quoted-literal edge cases. The clock must not read a hidden
local zone.

## Decision

Formatting functions that build text take a `std.mem.Allocator` and return a sentinel slice, or take
a caller buffer and return a slice into it. `Date.formatTo` formats into a bounded temporary and
copies exactly the text, so a caller buffer of exactly the needed size succeeds even though the C
formatter writes a terminator. `Date.format` implements `std.fmt` and writes `YYYY/MM/DD`, so `{f}`
works in `std.fmt`.

Parsing has two closed grammars, both delegated to the C core: strict `year month day` and the
lenient month-name form. The Zig errors are `InvalidCharacter`, `WrongGroupCount`, `NumberTooLong`,
`Ambiguous`, `Unrecognized`, `OutOfRange`, `InvalidMonth` and `InvalidDay`. `tryParse` and
`tryParseLenient` return options.

Clock functions take a Unix reading and a fixed offset in minutes east of UTC, or a `Zone` value for
Nepal or UTC. `todayNepal` uses the historical Nepal offset rule implemented by C. No function reads
the process's local time zone or a system clock.

## Consequences

The allocation policy is visible in every signature. A program can format without an allocator by
passing a stack buffer, and a program that wants the convenience gets an owned string it can free
with the same allocator. Tests can pin a date to a literal Unix instant.
