//! Bikram Sambat dates, conversion, arithmetic, formatting, parsing and clocks.

const std = @import("std");
const c = @import("c.zig");
const fiscal = @import("fiscal.zig");
const range = @import("range.zig");
const shared = @import("generated/shared_data.zig");

pub const Error = error{
    OutOfRange,
    InvalidMonth,
    InvalidDay,
    InvalidGregorian,
    InvalidCharacter,
    WrongGroupCount,
    NumberTooLong,
    Ambiguous,
    Unrecognized,
    InvalidDate,
    NoOverlap,
    OutOfMemory,
    NoSpace,
};

/// A failure kind of the strict or lenient parser.
pub const ParseErrorKind = enum {
    invalid_character,
    wrong_group_count,
    number_too_long,
    ambiguous,
    unrecognized,
    out_of_range,
    invalid_month,
    invalid_day,
};

pub const Month = enum(u8) {
    baishakh = 1,
    jestha = 2,
    ashad = 3,
    shrawan = 4,
    bhadra = 5,
    ashoj = 6,
    kartik = 7,
    mangsir = 8,
    poush = 9,
    magh = 10,
    falgun = 11,
    chaitra = 12,

    pub fn number(self: Month) u8 {
        return @backingInt(self);
    }

    pub fn englishName(self: Month) []const u8 {
        return month_names_en[@backingInt(self) - 1];
    }

    pub fn nepaliName(self: Month) []const u8 {
        return month_names_ne[@backingInt(self) - 1];
    }
};

pub const Weekday = enum(u8) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,

    pub fn englishName(self: Weekday) []const u8 {
        return weekday_names_en[@backingInt(self)];
    }

    pub fn nepaliName(self: Weekday) []const u8 {
        return weekday_names_ne[@backingInt(self)];
    }
};

pub const Quarter = enum(u8) {
    q1 = 1,
    q2 = 2,
    q3 = 3,
    q4 = 4,

    pub fn number(self: Quarter) u8 {
        return @backingInt(self);
    }

    /// The quarter that contains `month`, Shrawan to Ashad.
    pub fn containing(month: Month) Quarter {
        return switch (@backingInt(month)) {
            4, 5, 6 => .q1,
            7, 8, 9 => .q2,
            10, 11, 12 => .q3,
            else => .q4,
        };
    }
};

pub const MonthOverflow = enum(c_int) {
    clamp = 0,
    spill = 1,
};

pub const Lang = enum(c_int) {
    en = 0,
    ne = 1,
};

/// A fixed offset or the one named zone this package knows. There is no
/// time-zone database; callers that need another zone pass minutes east of UTC.
pub const Zone = enum {
    nepal,
    utc,

    pub fn offsetMinutes(self: Zone) i32 {
        return switch (self) {
            .nepal => nepal_offset_minutes,
            .utc => 0,
        };
    }
};

pub const Order = enum(c_int) {
    ymd = 0,
    ydm = 1,
    myd = 2,
    mdy = 3,
    dym = 4,
    dmy = 5,
};

pub const Separator = enum(c_int) {
    slash = '/',
    backslash = '\\',
    dot = '.',
    underscore = '_',
    dash = '-',
    space = ' ',
};

pub const ShortOptions = struct {
    order: Order = .ymd,
    separator: Separator = .slash,
    pad: bool = true,
    lang: Lang = .en,
};

pub const LongOptions = struct {
    weekday: bool = false,
    year: bool = true,
    pad: bool = true,
    lang: Lang = .en,
};

pub const NepaliMonth = Month;
pub const NepaliWeekday = Weekday;

pub const month_names_en = [_][]const u8{
    "Baishakh", "Jestha",  "Ashad", "Shrawan", "Bhadra", "Ashoj",
    "Kartik",   "Mangsir", "Poush", "Magh",    "Falgun", "Chaitra",
};

pub const month_names_ne = [_][]const u8{
    "बैशाख",
    "जेठ",
    "असार",
    "साउन",
    "भदौ",
    "असोज",
    "कार्तिक",
    "मंसिर",
    "पुष",
    "माघ",
    "फागुन",
    "चैत",
};

pub const weekday_names_en = [_][]const u8{
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
};

pub const weekday_names_ne = [_][]const u8{
    "आइतवार",
    "सोमवार",
    "मङ्गलवार",
    "बुधवार",
    "बिहिवार",
    "शुक्रवार",
    "शनिवार",
};

/// The Gregorian calendar date at midnight, without a zone.
pub const Gregorian = struct {
    year: i32,
    month: u8,
    day: u8,

    pub const min = Gregorian{ .year = 1844, .month = 4, .day = 11 };
    pub const max = Gregorian{ .year = 2143, .month = 4, .day = 15 };

    pub fn eql(self: Gregorian, other: Gregorian) bool {
        return self.year == other.year and self.month == other.month and self.day == other.day;
    }
};

/// The signed calendar distance between two dates.
pub const DateDiff = struct {
    /// -1 when the second date is earlier, 1 otherwise.
    sign: i8,
    years: u16,
    months: u8,
    days: u8,
    /// Signed total days in the direction the value describes.
    total_days: i32,

    pub fn negative(self: DateDiff) bool {
        return self.sign < 0;
    }
};

pub fn checkStatus(status: c.status) Error!void {
    return check(status);
}

/// Maps the integer status of the patro half, which has its own declarations.
pub fn checkStatusRaw(value: c_int) Error!void {
    return check(@fromBackingInt(@intCast(value)));
}

fn check(status: c.status) Error!void {
    return switch (status) {
        .ok => {},
        .out_of_range => error.OutOfRange,
        .invalid_month => error.InvalidMonth,
        .invalid_day => error.InvalidDay,
        .invalid_gregorian => error.InvalidGregorian,
        .invalid_character => error.InvalidCharacter,
        .wrong_group_count => error.WrongGroupCount,
        .number_too_long => error.NumberTooLong,
        .ambiguous => error.Ambiguous,
        .unrecognized => error.Unrecognized,
        .invalid_date => error.InvalidDate,
        .null_argument => error.InvalidDate,
        .no_overlap => error.NoOverlap,
    };
}

fn intOr(value: i64, comptime err: Error) Error!c_int {
    if (value < std.math.minInt(c_int) or value > std.math.maxInt(c_int)) return err;
    return @intCast(value);
}

/// A Bikram Sambat date between 1901-01-01 and 2199-12-30.
///
/// Values are immutable. The type is deliberately small (four bytes) because
/// the C core stores the serial day internally.
pub const Date = struct {
    value: c.date,

    pub const min = Date{ .value = .{ .value = shared.min_serial + 1 } };
    pub const max = Date{ .value = .{ .value = shared.max_serial + 1 } };

    /// Builds a date from BS `year`, `month` and `day`, checking them in that order.
    pub fn fromBs(year_bs: i64, month_bs: i64, day_bs: i64) Error!Date {
        const y = try intOr(year_bs, error.OutOfRange);
        const m = try intOr(month_bs, error.InvalidMonth);
        const d = try intOr(day_bs, error.InvalidDay);
        var out: c.date = undefined;
        try check(c.nepdate_from_bs(y, m, d, &out));
        return .{ .value = out };
    }

    /// Parses `year month day` in that order, strictly (PARSING section 1).
    pub fn parse(text: []const u8) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_parse(text.ptr, text.len, &out));
        return .{ .value = out };
    }

    /// Parses human input leniently (PARSING section 2).
    pub fn parseLenient(text: []const u8) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_parse_lenient(text.ptr, text.len, &out));
        return .{ .value = out };
    }

    pub fn tryParse(text: []const u8) ?Date {
        return parse(text) catch null;
    }

    pub fn tryParseLenient(text: []const u8) ?Date {
        return parseLenient(text) catch null;
    }

    /// Converts a Gregorian date. The time of day does not exist in this type.
    pub fn fromGregorian(year_ad: i64, month_ad: i64, day_ad: i64) Error!Date {
        const y = try intOr(year_ad, error.OutOfRange);
        const m = try intOr(month_ad, error.InvalidGregorian);
        const d = try intOr(day_ad, error.InvalidGregorian);
        var out: c.date = undefined;
        try check(c.nepdate_from_ad(y, m, d, &out));
        return .{ .value = out };
    }

    /// Converts the instant `unix_seconds` read at `offset_minutes` east of UTC.
    pub fn fromUnix(unix_seconds: i64, offset_minutes: i32) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_from_unix(unix_seconds, offset_minutes, &out));
        return .{ .value = out };
    }

    /// The date of a `YYYYMMDD` integer, for example `20810415`.
    pub fn fromYmd(ymd_value: i64) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_from_ymd_int(ymd_value, &out));
        return .{ .value = out };
    }

    /// Reads the canonical `YYYY-MM-DD` text, optionally wrapped in JSON quotes.
    pub fn fromJson(text: []const u8) Error!Date {
        if (text.len >= 2 and text[0] == '"' and text[text.len - 1] == '"') {
            return parse(text[1 .. text.len - 1]);
        }
        if (std.mem.eql(u8, text, "null")) return error.Unrecognized;
        return parse(text);
    }

    /// Today at `offset_minutes` east of UTC for the supplied Unix clock reading.
    pub fn today(offset_minutes: i32, unix_seconds: i64) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_today(offset_minutes, unix_seconds, &out));
        return .{ .value = out };
    }

    /// Today in Nepal for the supplied Unix clock reading.
    pub fn todayNepal(unix_seconds: i64) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_today_nepal(unix_seconds, &out));
        return .{ .value = out };
    }

    /// Today in a named zone for the supplied Unix clock reading.
    pub fn todayIn(zone: Zone, unix_seconds: i64) Error!Date {
        return today(zone.offsetMinutes(), unix_seconds);
    }

    /// The same date as `today`; the time of day is discarded.
    pub fn now(offset_minutes: i32, unix_seconds: i64) Error!Date {
        return today(offset_minutes, unix_seconds);
    }

    pub fn isDefault(self: Date) bool {
        return self.value.value == 0;
    }

    pub fn isValid(self: Date) bool {
        return validRange(self.value);
    }

    pub fn year(self: Date) i32 {
        var out: c.ymd = undefined;
        _ = c.nepdate_to_bs(self.value, &out);
        return out.year;
    }

    pub fn month(self: Date) Month {
        var out: c.month = undefined;
        _ = c.nepdate_month_of(self.value, &out);
        return @fromBackingInt(@intCast(@backingInt(out)));
    }

    pub fn monthNumber(self: Date) u8 {
        return @backingInt(self.month());
    }

    pub fn day(self: Date) u8 {
        var out: c.ymd = undefined;
        _ = c.nepdate_to_bs(self.value, &out);
        return @intCast(out.day);
    }

    pub fn dayOfWeek(self: Date) Weekday {
        var out: c.weekday = undefined;
        _ = c.nepdate_weekday_of(self.value, &out);
        return @fromBackingInt(@intCast(@backingInt(out)));
    }

    pub fn weekday(self: Date) Weekday {
        return self.dayOfWeek();
    }

    pub fn dayOfYear(self: Date) u16 {
        var out: c_int = undefined;
        _ = c.nepdate_day_of_year(self.value, &out);
        return @intCast(out);
    }

    pub fn monthLength(self: Date) u8 {
        var out: c_int = undefined;
        _ = c.nepdate_month_length(self.value, &out);
        return @intCast(out);
    }

    pub fn yearLength(self: Date) u16 {
        var out: c_int = undefined;
        _ = c.nepdate_year_length(self.value, &out);
        return @intCast(out);
    }

    pub fn lastDayOfMonth(self: Date) Date {
        var out: c.date = undefined;
        _ = c.nepdate_last_day_of_month(self.value, &out);
        return .{ .value = out };
    }

    /// The C# `MonthEndDate()` member.
    pub fn monthEndDate(self: Date) Date {
        return self.lastDayOfMonth();
    }

    pub fn firstDayOfMonth(self: Date) Date {
        var out: c.date = undefined;
        _ = c.nepdate_first_day_of_month(self.value, &out);
        return .{ .value = out };
    }

    pub fn eql(self: Date, other: Date) bool {
        return self.compare(other) == .eq;
    }

    pub fn compare(self: Date, other: Date) std.math.Order {
        var out: c_int = undefined;
        _ = c.nepdate_compare(self.value, other.value, &out);
        return switch (out) {
            -1 => .lt,
            0 => .eq,
            else => .gt,
        };
    }

    pub fn lessThan(self: Date, other: Date) bool {
        return self.compare(other) == .lt;
    }

    pub fn lessThanOrEqual(self: Date, other: Date) bool {
        return self.compare(other) != .gt;
    }

    pub fn greaterThan(self: Date, other: Date) bool {
        return self.compare(other) == .gt;
    }

    pub fn greaterThanOrEqual(self: Date, other: Date) bool {
        return self.compare(other) != .lt;
    }

    pub fn addDays(self: Date, days: i32) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_add_days(self.value, days, &out));
        return .{ .value = out };
    }

    pub fn addMonths(self: Date, months: i32, overflow: MonthOverflow) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_add_months(self.value, months, @fromBackingInt(@intCast(@backingInt(overflow))), &out));
        return .{ .value = out };
    }

    pub fn addYears(self: Date, years: i32, overflow: MonthOverflow) Error!Date {
        var out: c.date = undefined;
        try check(c.nepdate_add_years(self.value, years, @fromBackingInt(@intCast(@backingInt(overflow))), &out));
        return .{ .value = out };
    }

    /// Signed days from this date to `other`, positive when `other` is later.
    pub fn daysUntil(self: Date, other: Date) i32 {
        var out: i32 = undefined;
        _ = c.nepdate_diff_days(self.value, other.value, &out);
        return out;
    }

    /// The calendar breakdown from this date to `other`.
    pub fn diff(self: Date, other: Date) DateDiff {
        var out: c.date_diff = undefined;
        _ = c.nepdate_diff(self.value, other.value, &out);
        var total: i32 = undefined;
        _ = c.nepdate_diff_days(self.value, other.value, &total);
        return .{
            .sign = @intCast(out.sign),
            .years = @intCast(out.years),
            .months = @intCast(out.months),
            .days = @intCast(out.days),
            .total_days = total,
        };
    }

    /// The C# `-` operator direction: `this - other`.
    pub fn minus(self: Date, other: Date) DateDiff {
        var result = self.diff(other);
        result.total_days = -result.total_days;
        result.sign = -result.sign;
        return result;
    }

    /// The fiscal year that contains this date.
    pub fn fiscalYear(self: Date) fiscal.FiscalYear {
        return fiscal.FiscalYear.containing(self);
    }

    /// The fiscal quarter that contains this date.
    pub fn quarter(self: Date) Quarter {
        return Quarter.containing(self.month());
    }

    pub fn toGregorian(self: Date) Gregorian {
        var out: c.ymd = undefined;
        _ = c.nepdate_to_ad(self.value, &out);
        return .{ .year = out.year, .month = @intCast(out.month), .day = @intCast(out.day) };
    }

    /// The C# `EnglishDate` member.
    pub fn englishDate(self: Date) Gregorian {
        return self.toGregorian();
    }

    /// The C# `NepaliDate(DateTime)` constructor.
    pub fn fromEnglish(year_ad: i64, month_ad: i64, day_ad: i64) Error!Date {
        return fromGregorian(year_ad, month_ad, day_ad);
    }

    pub fn toRecord(self: Date) struct { year: i32, month: u8, day: u8 } {
        const y = self.year();
        return .{ .year = y, .month = self.monthNumber(), .day = self.day() };
    }

    pub fn ymd(self: Date) i64 {
        var out: i64 = undefined;
        _ = c.nepdate_to_ymd_int(self.value, &out);
        return out;
    }

    /// True when this is today at `offset_minutes` for the supplied clock.
    pub fn isToday(self: Date, offset_minutes: i32, unix_seconds: i64) bool {
        var out: bool = undefined;
        _ = c.nepdate_is_today(self.value, offset_minutes, unix_seconds, &out);
        return out;
    }

    pub fn isYesterday(self: Date, offset_minutes: i32, unix_seconds: i64) bool {
        var out: bool = undefined;
        _ = c.nepdate_is_yesterday(self.value, offset_minutes, unix_seconds, &out);
        return out;
    }

    pub fn isTomorrow(self: Date, offset_minutes: i32, unix_seconds: i64) bool {
        var out: bool = undefined;
        _ = c.nepdate_is_tomorrow(self.value, offset_minutes, unix_seconds, &out);
        return out;
    }

    /// `YYYY-MM-DD` in ASCII digits.
    pub fn toJsonAlloc(self: Date, allocator: std.mem.Allocator) Error![:0]u8 {
        return formatIso(self, allocator);
    }

    /// `YYYY/MM/DD`, the default display.
    pub fn toStringAlloc(self: Date, allocator: std.mem.Allocator) Error![:0]u8 {
        const needed = c.nepdate_format(self.value, null, .english, null, 0);
        if (needed == 0) return error.InvalidDate;
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_format(self.value, null, .english, buffer.ptr, needed + 1);
        return buffer;
    }

    /// The short format: the three fields in `options.order`.
    pub fn shortAlloc(self: Date, allocator: std.mem.Allocator, options: ShortOptions) Error![:0]u8 {
        const needed = c.nepdate_format_short(
            self.value,
            @fromBackingInt(@intCast(@backingInt(options.order))),
            @fromBackingInt(@intCast(@backingInt(options.separator))),
            options.pad,
            @fromBackingInt(@intCast(@backingInt(options.lang))),
            null,
            0,
        );
        if (needed == 0) return error.InvalidDate;
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_format_short(
            self.value,
            @fromBackingInt(@intCast(@backingInt(options.order))),
            @fromBackingInt(@intCast(@backingInt(options.separator))),
            options.pad,
            @fromBackingInt(@intCast(@backingInt(options.lang))),
            buffer.ptr,
            needed + 1,
        );
        return buffer;
    }

    /// The long format `[Weekday, ]Month day[, year]`.
    pub fn longAlloc(self: Date, allocator: std.mem.Allocator, options: LongOptions) Error![:0]u8 {
        const c_options = c.long_options{
            .weekday = options.weekday,
            .year = options.year,
            .pad = options.pad,
        };
        const needed = c.nepdate_format_long(
            self.value,
            c_options,
            @fromBackingInt(@intCast(@backingInt(options.lang))),
            null,
            0,
        );
        if (needed == 0) return error.InvalidDate;
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_format_long(
            self.value,
            c_options,
            @fromBackingInt(@intCast(@backingInt(options.lang))),
            buffer.ptr,
            needed + 1,
        );
        return buffer;
    }

    /// The custom pattern language of FORMATTING section 5.
    pub fn formatAlloc(
        self: Date,
        allocator: std.mem.Allocator,
        pattern: []const u8,
        lang: Lang,
    ) Error![:0]u8 {
        const pattern_z = try allocator.allocSentinel(u8, pattern.len, 0);
        @memcpy(pattern_z[0..pattern.len], pattern);
        defer allocator.free(pattern_z);
        const needed = c.nepdate_format(
            self.value,
            pattern_z.ptr,
            @fromBackingInt(@intCast(@backingInt(lang))),
            null,
            0,
        );
        if (needed == 0) return error.InvalidDate;
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_format(
            self.value,
            pattern_z.ptr,
            @fromBackingInt(@intCast(@backingInt(lang))),
            buffer.ptr,
            needed + 1,
        );
        return buffer;
    }

    /// Writes the default display into `buffer`, or returns `NoSpace`.
    pub fn write(self: Date, buffer: []u8) Error![]const u8 {
        return self.formatTo(buffer, "", .en);
    }

    /// Writes the short form into `buffer` without allocating.
    pub fn shortTo(self: Date, buffer: []u8, options: ShortOptions) Error![]const u8 {
        var temporary: [1024]u8 = undefined;
        const needed = c.nepdate_format_short(
            self.value,
            @fromBackingInt(@intCast(@backingInt(options.order))),
            @fromBackingInt(@intCast(@backingInt(options.separator))),
            options.pad,
            @fromBackingInt(@intCast(@backingInt(options.lang))),
            &temporary,
            temporary.len,
        );
        if (needed == 0) return error.InvalidDate;
        if (needed > buffer.len or needed >= temporary.len) return error.NoSpace;
        @memcpy(buffer[0..needed], temporary[0..needed]);
        return buffer[0..needed];
    }

    /// Writes the long form into `buffer` without allocating.
    pub fn longTo(self: Date, buffer: []u8, options: LongOptions) Error![]const u8 {
        const c_options = c.long_options{
            .weekday = options.weekday,
            .year = options.year,
            .pad = options.pad,
        };
        var temporary: [1024]u8 = undefined;
        const needed = c.nepdate_format_long(
            self.value,
            c_options,
            @fromBackingInt(@intCast(@backingInt(options.lang))),
            &temporary,
            temporary.len,
        );
        if (needed == 0) return error.InvalidDate;
        if (needed > buffer.len or needed >= temporary.len) return error.NoSpace;
        @memcpy(buffer[0..needed], temporary[0..needed]);
        return buffer[0..needed];
    }

    /// Writes a pattern into `buffer`, or returns `NoSpace`.
    ///
    /// The formatter's C core terminates its output, so the call formats into
    /// a bounded temporary buffer and copies exactly the text. Patterns whose
    /// output exceeds 1023 bytes are not supported here; use
    /// `formatAlloc` for those.
    pub fn formatTo(
        self: Date,
        buffer: []u8,
        pattern: []const u8,
        lang: Lang,
    ) Error![]const u8 {
        var pattern_buffer: [512]u8 = undefined;
        if (pattern.len >= pattern_buffer.len) return error.NoSpace;
        @memcpy(pattern_buffer[0..pattern.len], pattern);
        pattern_buffer[pattern.len] = 0;
        var temporary: [1024]u8 = undefined;
        const needed = c.nepdate_format(
            self.value,
            @ptrCast(&pattern_buffer),
            @fromBackingInt(@intCast(@backingInt(lang))),
            &temporary,
            temporary.len,
        );
        if (needed == 0) return error.InvalidDate;
        if (needed > buffer.len or needed >= temporary.len) return error.NoSpace;
        @memcpy(buffer[0..needed], temporary[0..needed]);
        return buffer[0..needed];
    }

    /// Integration with `std.fmt`: `{f}` writes `YYYY/MM/DD`.
    pub fn format(self: Date, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var buffer: [16]u8 = undefined;
        const text = self.write(&buffer) catch return error.WriteFailed;
        try writer.writeAll(text);
    }

    /// Equality is value equality of the packed day.
    pub fn hash(self: Date) u32 {
        return @bitCast(self.value.value);
    }
};

fn formatIso(value: Date, allocator: std.mem.Allocator) Error![:0]u8 {
    const needed = c.nepdate_format_iso(value.value, null, 0);
    if (needed == 0) return error.InvalidDate;
    const buffer = try allocator.allocSentinel(u8, needed, 0);
    errdefer allocator.free(buffer);
    _ = c.nepdate_format_iso(value.value, buffer.ptr, needed + 1);
    return buffer;
}

fn validRange(value: c.date) bool {
    var out: c.ymd = undefined;
    return c.nepdate_to_bs(value, &out) == .ok;
}

/// Converts Gregorian dates in input order.
pub fn toNepaliDates(dates: []const Gregorian, out: []Date) Error![]Date {
    if (out.len < dates.len) return error.NoSpace;
    for (dates) |item| {
        _ = try Date.fromGregorian(item.year, item.month, item.day);
    }
    for (dates, 0..) |item, i| {
        out[i] = try Date.fromGregorian(item.year, item.month, item.day);
    }
    return out[0..dates.len];
}

/// Converts BS dates to Gregorian dates in input order.
pub fn toEnglishDates(dates: []const Date, out: []Gregorian) Error![]Gregorian {
    if (out.len < dates.len) return error.NoSpace;
    for (dates) |item| {
        if (!item.isValid()) return error.InvalidDate;
    }
    for (dates, 0..) |item, i| out[i] = item.toGregorian();
    return out[0..dates.len];
}

/// Parses every text and converts it to its Gregorian date, in input order.
pub fn parseAll(texts: []const []const u8, out: []Gregorian) Error![]Gregorian {
    if (out.len < texts.len) return error.NoSpace;
    for (texts) |text| _ = try Date.parse(text);
    for (texts, 0..) |text, i| out[i] = (try Date.parse(text)).toGregorian();
    return out[0..texts.len];
}

pub fn batchToNepaliDates(dates: []const Gregorian, out: []Date) Error![]Date {
    return toNepaliDates(dates, out);
}

pub fn batchToEnglishDates(dates: []const Date, out: []Gregorian) Error![]Gregorian {
    return toEnglishDates(dates, out);
}

pub const Range = range.Range;
pub const RangeIterator = range.Iterator;
pub const RangeDayIterator = range.DayIterator;
pub const FiscalYear = fiscal.FiscalYear;

/// The version of this package, not of the vendored C core.
pub const version = "1.0.0-rc.1";

/// The version string compiled into the vendored C amalgamation.
pub fn vendorVersion() []const u8 {
    return std.mem.span(c.nepdate_version());
}

/// The Nepal offset used by `todayNepal`: UTC+05:45.
pub const nepal_offset_minutes: i32 = 345;

test "date basics" {
    const date = try Date.fromBs(2081, 4, 15);
    try std.testing.expectEqual(@as(i32, 2081), date.year());
    try std.testing.expectEqual(@as(u8, 4), date.monthNumber());
    try std.testing.expectEqual(@as(u8, 15), date.day());
    try std.testing.expectEqual(Month.shrawan, date.month());
    try std.testing.expectEqual(Weekday.tuesday, date.dayOfWeek());
    try std.testing.expectEqual(@as(u16, 109), date.dayOfYear());
    try std.testing.expectEqual(@as(u8, 32), date.monthLength());
    try std.testing.expectEqual(@as(u16, 366), date.yearLength());
}
