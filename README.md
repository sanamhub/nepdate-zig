<p align="center">
  <img src="https://raw.githubusercontent.com/sanamhub/nepdate-zig/main/docs/assets/nepdate-zig-128.png" width="128" alt="NepDate for Zig logo">
</p>

<h1 align="center">nepdate-zig</h1>

<p align="center">
  <a href="https://github.com/sanamhub/nepdate-zig/actions/workflows/ci.yml"><img src="https://github.com/sanamhub/nepdate-zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/sanamhub/nepdate-zig/releases"><img src="https://img.shields.io/github/v/release/sanamhub/nepdate-zig?include_prereleases&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/Zig-0.17.0-F7A41D?logo=zig&logoColor=black" alt="Zig 0.17.0">
  <a href="https://github.com/sanamhub/nepdate-zig/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
</p>

Bikram Sambat (Nepali calendar) dates for Zig: conversion to and from Gregorian, arithmetic,
formatting, parsing, ranges, fiscal years and the patro. Part of the NepDate family: the shared data
and spec live in the hub [`sanamhub/nepdate`](https://github.com/sanamhub/nepdate); the C# original
is [NepDate](https://github.com/RajuPrasai/NepDate).

> **Status:** `1.0.0-rc.1` is the first release of this port, and it is not on a registry yet. The
> API is listed in [docs/API.md](https://github.com/sanamhub/nepdate-zig/blob/main/docs/API.md) and
> may still change before 1.0.0. Patro data (tithi, holidays, events) is informational, not an
> official calendar.

One Zig package with two modules, released together from one tag:

- `nepdate`: dates, conversion, arithmetic, formatting, parsing, ranges and fiscal years.
- `nepdate_patro`: the patro (पात्रो, the Nepali almanac), with tithi, public holidays and events
  from BS 2077-01-01 to 2084-08-20. It imports `nepdate`.

The core and the patro compile the amalgamation of the C port at a pinned tag, so the calendar
tables and the patro data are the same bytes every other port uses. There is no time zone database:
`today` takes a fixed offset or the named Nepal zone and a Unix clock reading, so it never reads a
hidden local zone. Supported from BS 1901-01-01 to 2199-12-30 (AD 1844-04-11 to 2143-04-15).

## Install

Zig has no package registry. Fetch the release archive into your project and let Zig record the
hash in `build.zig.zon`:

```sh
zig fetch --save https://github.com/sanamhub/nepdate-zig/archive/refs/tags/v1.0.0-rc.1.tar.gz
```

Then add both modules to your executable in `build.zig`:

```zig
const dep = b.dependency("nepdate", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("nepdate", dep.module("nepdate"));
exe.root_module.addImport("nepdate_patro", dep.module("nepdate_patro"));
```

## Quick start

```zig
const nepdate = @import("nepdate");

const date = try nepdate.Date.fromBs(2081, 4, 15);
var buffer: [32]u8 = undefined;
const display = try date.write(&buffer); // 2081/04/15
const ad = date.englishDate();           // 2024-07-30
const long = try date.longAlloc(allocator, .{ .weekday = true }); // Tuesday, Shrawan 15, 2081
```

## Dates

A date is always a real day of the calendar, from 1901-01-01 to 2199-12-30 BS. The validating
constructor checks the year, then the month, then the day, and returns an error union. There is no
invalid or default date.

```zig
const date = try nepdate.Date.fromBs(2081, 4, 32);
_ = date.year();        // 2081
_ = date.monthNumber(); // 4
_ = date.day();         // 32
_ = date.dayOfWeek();   // .friday
_ = date.dayOfYear();   // 126
_ = date.monthLength(); // 32
_ = date.yearLength();  // 366
_ = nepdate.Date.min;   // 1901/01/01
_ = nepdate.Date.max;   // 2199/12/30
```

`yearLength` is the BS year length, 364 to 367 days, and replaces the C# `IsLeapYear()`, which
followed the Gregorian year. `lastDayOfMonth` and `monthEndDate` replace `MonthEndDate()`.

## Conversion and serialization

Convert a Gregorian date by its date part. The canonical text form is `YYYY-MM-DD`; the `YYYYMMDD`
integer is available both ways.

```zig
try nepdate.Date.fromGregorian(2024, 7, 30);
try nepdate.Date.fromYmd(20810415);
_ = (try nepdate.Date.fromBs(2081, 4, 15)).ymd(); // 20810415
const iso = try (try nepdate.Date.fromBs(2081, 4, 15)).toJsonAlloc(allocator); // 2081-04-15
_ = try nepdate.Date.fromJson(iso);
```

Batch conversion keeps input order. A single bad item fails the whole call before any result is
written.

```zig
var out: [1]nepdate.Date = undefined;
_ = try nepdate.toNepaliDates(&.{.{ .year = 2024, .month = 7, .day = 30 }}, &out);
var gregorian: [1]nepdate.Gregorian = undefined;
_ = try nepdate.toEnglishDates(&.{try nepdate.Date.fromBs(2081, 4, 15)}, &gregorian);
```

## Arithmetic

Months are whole numbers. When the day does not exist in the target month, `.clamp` uses the last
day and `.spill` carries the extra days into the next month. The named `daysUntil` is `other - this`;
`minus` keeps the C# `-` direction, `this - other`.

```zig
const date = try nepdate.Date.fromBs(2081, 4, 32);
_ = try date.addDays(30);                 // 2081-05-30
_ = try date.addMonths(2, .clamp);        // 2081-06-30
_ = try date.addMonths(2, .spill);        // 2081-07-02
_ = date.daysUntil(try nepdate.Date.fromBs(2081, 4, 16)); // 1
_ = (try nepdate.Date.fromBs(2081, 4, 16)).minus(date).totalDays; // 1
```

## Formatting

Short formats take an order, a separator, a padding flag and a language. The long form is
`[Weekday, ]Month day[, year]`. Nepali output uses Devanagari names and digits. Patterns accept
`yyyy`, `yy`, `MMMM`, `MMM`, `MM`, `M`, `dd`, `d`, a backslash escape and a quoted literal.

```zig
const date = try nepdate.Date.fromBs(2081, 4, 15);
const short = try date.shortAlloc(allocator, .{ .order = .dmy, .separator = .dash }); // 15-04-2081
const unicode = try date.shortAlloc(allocator, .{ .lang = .ne });                     // २०८१/०४/१५
const long = try date.longAlloc(allocator, .{});                                      // Shrawan 15, 2081
const pattern = try date.formatAlloc(allocator, "MMMM d, yyyy", .en);                  // Shrawan 15, 2081
```

`std.fmt` support is built in: `{f}` writes `YYYY/MM/DD`. Functions that build text take an
allocator or a caller buffer; nothing allocates behind your back.

## Parsing

The strict parser takes year, month and day in that order, with ASCII or Devanagari digits and the
separators `- / . _ \ space | ।`. The lenient parser accepts month names in English or Nepali, the
day before the year, and era markers such as `B.S.`. Both have non-throwing forms.

```zig
_ = try nepdate.Date.parse("2081/04/15");
_ = try nepdate.Date.parse("२०८१/०४/१५");
_ = try nepdate.Date.parseLenient("15 Shrawan 2081 B.S.");
_ = nepdate.Date.tryParse("2081/13/01");       // null
_ = nepdate.Date.tryParseLenient("15 Foo 2081"); // null
```

A parse failure is an error value: `InvalidCharacter`, `WrongGroupCount`, `NumberTooLong`,
`Ambiguous`, `Unrecognized`, `OutOfRange`, `InvalidMonth` or `InvalidDay`.

## Ranges

A range is inclusive and always has at least one day. It iterates its days and offers containment,
overlap, adjacency, intersection, union, difference, month and fiscal-quarter splits, an interval
walk, working days and weekend days.

```zig
const range = try nepdate.Range.of(
    try nepdate.Date.fromBs(2081, 4, 10),
    try nepdate.Date.fromBs(2081, 4, 20),
);
_ = range.length(); // 11
_ = range.contains(try nepdate.Date.fromBs(2081, 4, 15)); // true
const text = try range.formatAlloc(allocator); // 2081/04/10 - 2081/04/20
var iterator = range.iterator();
while (iterator.next()) |day| _ = day;
```

## Fiscal year

A fiscal year starts on 1 Shrawan and ends on the last day of Ashad. Quarters are Shrawan to Ashoj,
Kartik to Poush, Magh to Chaitra, and Baishakh to Ashad of the next year.

```zig
const fy = nepdate.FiscalYear.containing(try nepdate.Date.fromBs(2082, 1, 15));
_ = fy.year; // 2081
var label_buffer: [39]u8 = undefined;
_ = try fy.label(&label_buffer, .en); // 2081/82
const q4 = try fy.quarterRange(.q4);
_ = q4.start; // 2082-01-01
```

## Today

The clock and the zone are arguments, never a hidden local setting. Nepal is UTC+05:45. A named
`Zone` is available for `nepal` and `utc`; any other fixed offset is minutes east of UTC.

```zig
const instant: i64 = 1722364200; // 2024-07-30 18:30 UTC
_ = try nepdate.Date.todayNepal(instant);              // 2081-04-16
_ = try nepdate.Date.today(0, instant);                // 2081-04-15
_ = try nepdate.Date.todayIn(.nepal, instant);         // 2081-04-16
_ = (try nepdate.Date.fromBs(2081, 4, 16)).isToday(nepdate.nepal_offset_minutes, instant);
```

## Patro: tithi, holidays and events

The second module reads the compiled patro data. It covers BS 2077-01-01 to 2084-08-20; a day
outside that range has no tithi, is not a holiday and has no events.

```zig
const patro = @import("nepdate_patro");

var events: [8]patro.Event = undefined;
const info = try patro.infoInto(try nepdate.Date.fromBs(2081, 1, 1), &events);
_ = info.tithiEn();      // Panchami
_ = info.is_public_holiday; // true
_ = info.events[0].english; // New Year

const coverage = patro.coverage(); // 2077-01-01 to 2084-08-20
_ = coverage.length();             // 2793
```

`patro.info(allocator, date)` allocates the event list and has a `deinit`; `infoInto` uses your
buffer. `patro.publicHolidays(allocator)` and `publicHolidaysInto(buffer)` return the holiday dates
in ascending order.

## Supported versions and platforms

Zig 0.17.0 is the only supported compiler. The C amalgamation cross-compiles to `x86_64` and
`aarch64` on Linux, macOS and Windows; CI runs the tests natively on all three systems. The package
declares `minimum_zig_version = "0.17.0"`.

## Data and correctness

Every shared vector is asserted: every month boundary, every golden date, every add-days and
add-months row, the format matrix and pattern file, both parse files, every range operation and
split, the YYYYMMDD and bulk and serialization files, and all 299 year lengths. The tests also walk
every supported day and round-trip it through Gregorian and `YYYYMMDD`. The vendored C files are
checked against the release tag by `tools/check_vendor.py`, and the shared data is checked by the
generator's `--check` mode.

## Documentation

- [API reference](https://github.com/sanamhub/nepdate-zig/blob/main/docs/API.md)
- [Architecture decisions](https://github.com/sanamhub/nepdate-zig/blob/main/docs/adr/README.md)
- [Benchmarks](https://github.com/sanamhub/nepdate-zig/blob/main/docs/benchmarks.md)
- [Release runbook](https://github.com/sanamhub/nepdate-zig/blob/main/docs/runbooks/release.md)

## Benchmarks

B1 to B8 from the hub's benchmark protocol, against the C core this package wraps, are in
[docs/benchmarks.md](https://github.com/sanamhub/nepdate-zig/blob/main/docs/benchmarks.md). The
numbers there were taken on an idle machine, pinned to one performance core, and the idle check is recorded with the table.

## Contributing

Read [CONTRIBUTING.md](https://github.com/sanamhub/nepdate-zig/blob/main/CONTRIBUTING.md). The shared
calendar data and spec are in the hub and are never edited here.

## Credit

The calendar, the patro data and the behaviour are from NepDate, the C# library by
[Raju Prasai](https://github.com/RajuPrasai) and contributors. The C amalgamation is from
[`sanamhub/nepdate-c`](https://github.com/sanamhub/nepdate-c), which is the port this package
compiles. [NOTICE](https://github.com/sanamhub/nepdate-zig/blob/main/NOTICE) records both.

## License

MIT. See [LICENSE](https://github.com/sanamhub/nepdate-zig/blob/main/LICENSE).
