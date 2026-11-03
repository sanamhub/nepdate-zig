# API reference

`nepdate` is one Zig package with two modules. Import the core with
`@import("nepdate")` and the patro with `@import("nepdate_patro")`. Every
function that can reject input returns an error union; every function that
builds text takes an allocator or a caller buffer.

The tables below use the C# member as the first column, so a reader can compare
this port with `NepDate` directly. The Zig column is the name in this package.

## Dates, identity and comparison

```zig
const date = try nepdate.Date.fromBs(2081, 4, 15);
_ = date.year();          // 2081
_ = date.month();         // .shrawan
_ = date.day();           // 15
_ = date.englishDate();   // .{ .year = 2024, .month = 7, .day = 30 }
```

| C# member | Zig API | Notes |
|---|---|---|
| `NepaliDate(int yearBs, int monthBs, int dayBs)` | `Date.fromBs(year, month, day) !Date` | Accepts `i64`; checks year, then month, then day. |
| `NepaliDate(string rawNepaliDate)` | `Date.parse(text) !Date` | Strict parser. |
| `NepaliDate(string, bool autoAdjust, bool monthInMiddle)` | not ported | The heuristics are replaced by the strict and lenient parsers. |
| `NepaliDate(DateTime engDate)` | `Date.fromGregorian(year, month, day) !Date`, `Date.fromEnglish(...)` | The date part only. |
| `bool IsDefault { get; }` | `Date.isDefault()` | The Zig zero value is not a valid date; use `Date.isValid()` to test a value. |
| `int Year { get; }` | `Date.year() i32` | |
| `int Month { get; }` | `Date.month() Month`, `Date.monthNumber() u8` | |
| `int Day { get; }` | `Date.day() u8` | |
| `DateTime EnglishDate { get; }` | `Date.englishDate() Gregorian`, `Date.toGregorian()` | No time of day and no zone. |
| `DayOfWeek DayOfWeek { get; }` | `Date.dayOfWeek() Weekday`, `Date.weekday()` | Sunday is 0. |
| `int DayOfYear { get; }` | `Date.dayOfYear() u16` | 1-based in the BS year. |
| `int MonthEndDay { get; }` | `Date.monthLength() u8` | |
| `NepaliMonths MonthName { get; }` | `Date.month() Month` | |
| `static NepaliDate Today { get; }` | `Date.today(offset_minutes, unix_seconds)`, `Date.todayNepal(unix)`, `Date.todayIn(zone, unix)` | The zone and clock are explicit. |
| `static NepaliDate Now { get; }` | `Date.now(offset_minutes, unix_seconds)` | Same date as `today`. |
| `static readonly NepaliDate MinValue` | `Date.min` | 1901-01-01 BS. |
| `static readonly NepaliDate MaxValue` | `Date.max` | 2199-12-30 BS. |
| `NepaliDate MonthEndDate()` | `Date.monthEndDate()`, `Date.lastDayOfMonth()` | |
| `void Deconstruct(out int, out int, out int)` | `Date.toRecord()` | Returns a struct with `year`, `month`, `day`. |
| `bool IsLeapYear()` | `Date.yearLength() u16` | The BS year length, 364 to 367 days. |
| `bool IsToday()` | `Date.isToday(offset_minutes, unix_seconds)` | |
| `bool IsYesterday()` | `Date.isYesterday(offset_minutes, unix_seconds)` | |
| `bool IsTomorrow()` | `Date.isTomorrow(offset_minutes, unix_seconds)` | |
| `int CompareTo(NepaliDate)` | `Date.compare(other) std.math.Order` | |
| `int CompareTo(object)` | not ported | Zig has typed comparison. |
| `bool Equals(NepaliDate)` | `Date.eql(other)` | |
| `override bool Equals(object)` | `Date.eql(other)` | |
| `override int GetHashCode()` | `Date.hash() u32` | |
| `operator ==` | `Date.eql(other)` | Zig does not overload operators for structs. |
| `operator !=` | `!Date.eql(other)` | |
| `operator <` | `Date.lessThan(other)` | |
| `operator <=` | `Date.lessThanOrEqual(other)` | |
| `operator >` | `Date.greaterThan(other)` | |
| `operator >=` | `Date.greaterThanOrEqual(other)` | |

## Conversion and serialization

```zig
const date = try nepdate.Date.fromGregorian(2024, 7, 30);
_ = date.ymd();                      // 20810415
const iso = try date.toJsonAlloc(allocator); // 2081-04-15
```

| C# member | Zig API | Notes |
|---|---|---|
| `DateTimeExtensions.ToNepaliDate(this DateTime)` | `Date.fromGregorian(year, month, day)` | |
| `SmartParsingExtensions.ToNepaliDate(this string)` | `Date.parseLenient(text) !Date` | |
| `SmartParsingExtensions.TryToNepaliDate(this string, out ...)` | `Date.tryParseLenient(text) ?Date` | |
| `BulkConvert.ToNepaliDates(IEnumerable<DateTime>, bool)` | `nepdate.toNepaliDates(dates, out) ![]Date` | Keeps input order; all or nothing. |
| `BulkConvert.ToEnglishDates(IEnumerable<string>, bool)` | `nepdate.parseAll(texts, out) ![]Gregorian` | |
| `BulkConvert.ToEnglishDates(IEnumerable<NepaliDate>, bool)` | `nepdate.toEnglishDates(dates, out) ![]Gregorian` | |
| `BatchProcessToNepaliDates(...)` | `nepdate.batchToNepaliDates(dates, out)` | Same operation as bulk conversion. |
| `BatchProcessToEnglishDates(...)` | `nepdate.batchToEnglishDates(dates, out)` | Same operation as bulk conversion. |
| `NepaliDateTypeConverter` | `Date.fromYmd(value) !Date`, `Date.ymd() i64` | The `YYYYMMDD` integer form; the type is not ported. |
| `SystemTextJsonConverters.NepaliDateJsonConverter` | `Date.toJsonAlloc(allocator)`, `Date.fromJson(text)` | The native string hook. It reads and writes `YYYY-MM-DD`. |
| `NepaliDateObjectJsonConverter` | not ported | The object form is replaced by the canonical string. |
| Newtonsoft converters | not ported | The canonical string is the only serialized form. |
| `NepaliDateXmlSerializer` | not ported | The canonical string is the only serialized form. |
| `ConfigureForNepaliDate(JsonSerializerOptions, ...)` | not ported | Language-native JSON hooks are used instead. |
| `ConfigureForNepaliDate(JsonSerializerSettings, ...)` | not ported | Language-native JSON hooks are used instead. |

## Arithmetic

```zig
const date = try nepdate.Date.fromBs(2081, 4, 32);
_ = try date.addMonths(2, .clamp); // 2081-06-30
_ = try date.addMonths(2, .spill); // 2081-07-02
_ = date.daysUntil(try nepdate.Date.fromBs(2081, 5, 1)); // 1
```

| C# member | Zig API | Notes |
|---|---|---|
| `NepaliDate AddMonths(double, bool)` | `Date.addMonths(months: i32, overflow) !Date` | Fractional months are not ported; `overflow` is `.clamp` or `.spill`. |
| `NepaliDate AddDays(double)` | `Date.addDays(days: i32) !Date` | Fractional days are not ported. |
| `NepaliDate AddYears(int, bool)` | `Date.addYears(years: i32, overflow) !Date` | Calls the month path with twelve times the years. |
| `TimeSpan Subtract(NepaliDate)` | `Date.daysUntil(other) i32` | `other - this`. |
| `operator -(NepaliDate, NepaliDate)` | `Date.minus(other) DateDiff` | `this - other`; the sign is the opposite of `daysUntil`. |

`DateDiff` carries `sign`, `years`, `months`, `days` and `total_days`.

## Formatting

```zig
const date = try nepdate.Date.fromBs(2081, 4, 15);
var buffer: [32]u8 = undefined;
_ = try date.write(&buffer);                 // 2081/04/15
_ = try date.shortAlloc(allocator, .{});    // 2081/04/15
_ = try date.longAlloc(allocator, .{});     // Shrawan 15, 2081
_ = try date.formatAlloc(allocator, "MMM yyyy", .en); // Shr 2081
```

| C# member | Zig API | Notes |
|---|---|---|
| `override string ToString()` | `Date.write(buffer)`, `Date.toStringAlloc(allocator)`, `{f}` | `YYYY/MM/DD`. |
| `string ToString(DateFormats, Separators, bool)` | `Date.shortAlloc(allocator, ShortOptions)` | Order, separator, padding and language. |
| `string ToLongDateString(bool, bool, bool)` | `Date.longAlloc(allocator, LongOptions)` | `weekday`, `year`, `pad`, `lang`. |
| `string ToUnicodeString(...)` | `Date.shortAlloc(allocator, .{ .lang = .ne })` | |
| `string ToLongDateUnicodeString(...)` | `Date.longAlloc(allocator, .{ .lang = .ne })` | |
| `string ToString(string, IFormatProvider)` | `Date.formatAlloc(allocator, pattern, lang)` | Standard patterns and the custom pattern language. |
| `bool ISpanFormattable.TryFormat(...)` | `Date.formatTo(buffer, pattern, lang)` | Returns `NoSpace` when the text does not fit. |
| `enum DateFormats` | `Order` | `ymd`, `ydm`, `myd`, `mdy`, `dym`, `dmy`. |
| `enum Separators` | `Separator` | `slash`, `backslash`, `dot`, `underscore`, `dash`, `space`. |
| `enum NepaliMonths` | `Month` | `baishakh` to `chaitra`; `englishName` and `nepaliName`. |

## Parsing

```zig
_ = try nepdate.Date.parse("२०८१/०४/१५");
_ = try nepdate.Date.parseLenient("15 Shrawan 2081 B.S.");
_ = nepdate.Date.tryParse("2081/13/01"); // null
```

| C# member | Zig API | Notes |
|---|---|---|
| `static NepaliDate Parse(string)` | `Date.parse(text) !Date` | Strict parser. |
| `static NepaliDate Parse(string, bool, bool)` | not ported | The auto-adjust heuristics are replaced. |
| `static bool TryParse(string, out ...)` | `Date.tryParse(text) ?Date` | |
| `static bool TryParse(string, out ..., bool, bool)` | not ported | The auto-adjust heuristics are replaced. |
| `IParsable<NepaliDate>` | `Date.parse` | The language trait is not separate. |
| `ISpanParsable<NepaliDate>` | `Date.parse` | It accepts a byte slice. |
| `SmartDateParser.Parse(string)` | `Date.parseLenient(text) !Date` | |
| `SmartDateParser.TryParse(string, out ...)` | `Date.tryParseLenient(text) ?Date` | |
| `InvalidNepaliDateFormatException` | `Error` | The error set has the parse kinds. |

## Ranges

```zig
const range = try nepdate.Range.of(
    try nepdate.Date.fromBs(2081, 4, 10),
    try nepdate.Date.fromBs(2081, 4, 20),
);
_ = range.length(); // 11
_ = range.contains(try nepdate.Date.fromBs(2081, 4, 15)); // true
```

| C# member | Zig API | Notes |
|---|---|---|
| `readonly struct NepaliDateRange` | `Range` | Inclusive, non-empty. |
| `NepaliDateRange(NepaliDate, NepaliDate)` | `Range.of(start, end) !Range` | Refuses `start > end`. |
| `NepaliDate Start { get; }` | `Range.start` | |
| `NepaliDate End { get; }` | `Range.end` | |
| `bool IsEmpty { get; }` | not exposed | A range always has at least one day. |
| `int Length { get; }` | `Range.length() i32` | |
| `static SingleDay(NepaliDate)` | `Range.single(date)` | |
| `static FromDayCount(NepaliDate, int)` | `Range.fromDayCount(start, days) !Range` | |
| `static ForMonth(int, int)` | `Range.forMonth(year, month) !Range` | |
| `static ForFiscalYear(int)` | `Range.forFiscalYear(year) !Range` | |
| `static ForCalendarYear(int)` | `Range.forCalendarYear(year) !Range` | |
| `static CurrentMonth()` | `Range.currentMonth(offset, unix) !Range` | |
| `static CurrentFiscalYear()` | `Range.currentFiscalYear(offset, unix) !Range` | |
| `static CurrentCalendarYear()` | `Range.currentCalendarYear(offset, unix) !Range` | |
| `bool Contains(NepaliDate)` | `Range.contains(date)` | |
| `bool Contains(NepaliDateRange)` | `Range.containsRange(other)` | |
| `bool Overlaps(NepaliDateRange)` | `Range.overlaps(other)` | |
| `bool IsAdjacentTo(NepaliDateRange)` | `Range.isAdjacentTo(other)` | False at the data ends. |
| `NepaliDateRange Intersect(...)` | `Range.intersect(other) !Range` | `NoOverlap` when disjoint. |
| `NepaliDateRange Union(...)` | `Range.unionWith(other)` | The smallest covering range. |
| `NepaliDateRange[] Except(...)` | `Range.except(other, *[2]Range)` | Zero, one or two pieces. `exceptAlloc` allocates. |
| `NepaliDateRange[] SplitByMonth()` | `Range.splitByMonth(allocator)` | |
| `NepaliDateRange[] SplitByFiscalQuarter()` | `Range.splitByFiscalQuarter(allocator)` | |
| `IEnumerable<NepaliDate> DatesWithInterval(int)` | `Range.datesWithInterval(interval) !DayIterator` | |
| `IEnumerable<NepaliDate> WorkingDays(bool)` | `Range.workingDays(exclude_sunday) !DayIterator` | |
| `IEnumerable<NepaliDate> WeekendDays(bool)` | `Range.weekendDays(include_sunday) !DayIterator` | |
| `IEnumerator<NepaliDate> GetEnumerator()` | `Range.iterator()` | |
| `override string ToString()` | `Range.formatAlloc(allocator)`, `{f}` | `start - end`. |
| `string ToString(DateFormats, Separators)` | `Range.formatShortAlloc(allocator, order, separator, lang)` | |
| `Equals`, `GetHashCode`, `==`, `!=` | `Range.eql(other)`, `Range.hash()` | Value equality of the bounds. |

## Fiscal year

```zig
const fy = nepdate.FiscalYear.containing(try nepdate.Date.fromBs(2082, 1, 15));
_ = fy.year; // 2081
_ = try fy.start(); // 2081-04-01
_ = try fy.end();   // 2082-03-31
```

| C# member | Zig API | Notes |
|---|---|---|
| `enum FiscalYearQuarters` | `Quarter` | `q1` to `q4`; `Quarter.containing(month)`. |
| `FiscalYearStartDate(int)` | `FiscalYear.containing(date).start()` | |
| `FiscalYearEndDate(int)` | `.end()` | |
| `FiscalYearStartAndEndDate(int)` | `.range()` | |
| `FiscalYearQuarterStartDate(FiscalYearQuarters, int)` | `.quarterStart(quarter)` | |
| `FiscalYearQuarterEndDate(FiscalYearQuarters, int)` | `.quarterEnd(quarter)` | |
| `FiscalYearQuarterStartAndEndDate(...)` | `.quarterRange(quarter)` | |
| `GetFiscalYearStartDate(int)` | `FiscalYear.init(year)`, `.start()` | |
| `GetFiscalYearEndDate(int)` | `.end()` | |
| `GetFiscalYearStartAndEndDate(int)` | `.range()` | |
| `GetFiscalYearQuarterStartDate(int, int)` | not ported | Use the `Quarter` value. |
| `GetFiscalYearQuarterEndDate(int, int)` | not ported | Use the `Quarter` value. |
| `GetFiscalYearQuarterStartAndEndDate(int, int)` | not ported | Use the `Quarter` value. |

`FiscalYear.labelAlloc(allocator, lang)` and `FiscalYear.label(buffer, lang)` write `2081/82` in
English or Devanagari digits.

## Patro

```zig
const patro = @import("nepdate_patro");
var events: [8]patro.Event = undefined;
const info = try patro.infoInto(try nepdate.Date.fromBs(2081, 1, 1), &events);
_ = info.tithiEn();      // Panchami
_ = info.events[0].english; // New Year
```

| C# member | Zig API | Notes |
|---|---|---|
| `readonly struct CalendarInfo` | `patro.CalendarInfo` | Tithi, holiday flag and ordered events. |
| `string TithiNp { get; }` | `info.tithiNp()` | Empty outside the data range. |
| `string TithiEn { get; }` | `info.tithiEn()` | Empty outside the data range. |
| `bool IsPublicHoliday { get; }` | `info.is_public_holiday` | |
| `string[] EventsNp { get; }` | `info.events`, `info.eventsNp(buffer)` | File order. |
| `string[] EventsEn { get; }` | `info.events`, `info.eventsEn(buffer)` | File order. |
| `CalendarInfo GetCalendarInfo()` | `patro.info(allocator, date)`, `patro.infoInto(date, buffer)` | `info` allocates and has `deinit`; `infoInto` uses your buffer. |

`patro.coverage()`, `patro.publicHolidays(allocator)` and `patro.publicHolidaysInto(buffer)` cover
the rest of the patro contract. `CalendarInfo.deinit(allocator)` frees the event list returned by
`info`; a value from `infoInto` borrows the caller's buffer and must not be deinitialized.
