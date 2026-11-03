# ADR-0005: the patro as a second module

- **Status:** accepted
- **Date:** 2026-11-04

## Context

The patro data is large (the C string pool is about 60 KB compiled) and changes on a different
rhythm from the calendar. Hub ADR-0004 requires a separate unit that depends on the core, and the
core must not contain any event strings.

## Decision

The package exposes two modules, `nepdate` and `nepdate_patro`. `nepdate_patro` imports `nepdate`
and compiles the same C amalgamation; the core module does not import the patro. The generated
patro tables live only in the patro half of the C file.

`CalendarInfo` is returned by `info(allocator, date)` and by `infoInto(date, buffer)`. The first owns
the event list and has `deinit`; the second borrows the caller's buffer and must not be
deinitialized. `publicHolidays` has the same pair. Name slices point into the static C string pool,
so only the list of structs is allocated, not the text.

## Consequences

A program that only converts dates links no patro code and no event strings. A program that needs
the patro pays for the strings and for one event-list allocation per day unless it uses the buffer
form. The two modules share a version and a release.
