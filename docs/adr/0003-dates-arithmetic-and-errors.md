# ADR-0003: dates, arithmetic and errors

- **Status:** accepted
- **Date:** 2026-11-04

## Context

C# `NepaliDate` is a struct with a default value that is not a date. A port that keeps a zero value
has to answer what `0000-00-00` means and which methods reject it. The C core stores a one-based
serial in four bytes and rejects a zero value as `NEPDATE_E_INVALID_DATE`.

## Decision

`Date` is a four-byte value wrapping the C serial. All constructors validate and return an error
union, so a `Date` made through the API is always a real day. Zig's zero value still exists because
the type is a struct; `Date.isDefault()` and `Date.isValid()` expose that state, and every accessor
on an invalid value returns a zero structure or an error rather than pretending it is a date.

Integer inputs that reach a C `int` are checked before the cast. `Date.fromYmd` takes `i64` and passes
it whole to the C function, which splits it with truncating division and validates each part. A value
wider than the internal type is an error, never a truncation.

Comparison is by serial. Zig does not overload struct operators, so `Date` has `eql`, `compare`,
`lessThan`, `lessThanOrEqual`, `greaterThan`, `greaterThanOrEqual` and `hash`. The names make the
direction explicit.

`DaysUntil` is `other - this`. `minus` is `this - other`, the direction of the C# `-` operator. Both
return `DateDiff` where `total_days` is signed in that direction.

## Consequences

There is no invalid date to carry around, and no default-valued date in a range. The cost is that
Zig callers write `try` at construction. The four-byte value makes arrays and range iterators cheap.
