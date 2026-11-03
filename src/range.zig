//! Inclusive ranges of Bikram Sambat dates.

const std = @import("std");
const core = @import("nepdate.zig");
const c = @import("c.zig");

/// Every day from `start` to `end`, both included. A range is never empty.
pub const Range = struct {
    start: core.Date,
    end: core.Date,

    pub fn of(start: core.Date, end: core.Date) core.Error!Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_make(start.value, end.value, &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn single(date: core.Date) Range {
        return .{ .start = date, .end = date };
    }

    pub fn fromDayCount(start: core.Date, day_count: i32) core.Error!Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_from_day_count(start.value, day_count, &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn forMonth(year: i64, month: i64) core.Error!Range {
        if (year < std.math.minInt(c_int) or year > std.math.maxInt(c_int)) return error.OutOfRange;
        if (month < std.math.minInt(c_int) or month > std.math.maxInt(c_int)) return error.InvalidMonth;
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_of_month(@intCast(year), @intCast(month), &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn forCalendarYear(year: i64) core.Error!Range {
        if (year < std.math.minInt(c_int) or year > std.math.maxInt(c_int)) return error.OutOfRange;
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_of_year(@intCast(year), &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn forFiscalYear(fiscal_year: i64) core.Error!Range {
        if (fiscal_year < std.math.minInt(c_int) or fiscal_year > std.math.maxInt(c_int)) {
            return error.OutOfRange;
        }
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_of_fiscal_year(@intCast(fiscal_year), &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn currentMonth(offset_minutes: i32, unix_seconds: i64) core.Error!Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_current_month(offset_minutes, unix_seconds, &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn currentFiscalYear(offset_minutes: i32, unix_seconds: i64) core.Error!Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_current_fiscal_year(offset_minutes, unix_seconds, &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn currentCalendarYear(offset_minutes: i32, unix_seconds: i64) core.Error!Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_current_calendar_year(offset_minutes, unix_seconds, &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn length(self: Range) i32 {
        var out: c_int = undefined;
        _ = c.nepdate_range_length(self.cValue(), &out);
        return out;
    }

    pub fn contains(self: Range, date: core.Date) bool {
        var out: bool = undefined;
        _ = c.nepdate_range_contains(self.cValue(), date.value, &out);
        return out;
    }

    pub fn containsRange(self: Range, other: Range) bool {
        var out: bool = undefined;
        _ = c.nepdate_range_contains_range(self.cValue(), other.cValue(), &out);
        return out;
    }

    pub fn overlaps(self: Range, other: Range) bool {
        var out: bool = undefined;
        _ = c.nepdate_range_overlaps(self.cValue(), other.cValue(), &out);
        return out;
    }

    pub fn isAdjacentTo(self: Range, other: Range) bool {
        var out: bool = undefined;
        _ = c.nepdate_range_is_adjacent_to(self.cValue(), other.cValue(), &out);
        return out;
    }

    pub fn intersect(self: Range, other: Range) core.Error!Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_intersect(self.cValue(), other.cValue(), &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    pub fn unionWith(self: Range, other: Range) Range {
        var out: c.range = undefined;
        _ = c.nepdate_range_union(self.cValue(), other.cValue(), &out);
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    /// The parts of this range that are not in `other`, into a two-element caller buffer.
    pub fn except(self: Range, other: Range, out: *[2]Range) core.Error![]Range {
        var c_out: [2]c.range = undefined;
        var written: usize = 0;
        try core.checkStatus(c.nepdate_range_except(
            self.cValue(),
            other.cValue(),
            &c_out,
            &written,
        ));
        for (c_out[0..written], 0..) |piece, i| {
            out[i] = .{ .start = .{ .value = piece.start }, .end = .{ .value = piece.end } };
        }
        return out[0..written];
    }

    /// The same as `except`, allocated by the caller's allocator.
    pub fn exceptAlloc(
        self: Range,
        allocator: std.mem.Allocator,
        other: Range,
    ) core.Error![]Range {
        var buffer: [2]Range = undefined;
        const pieces = try self.except(other, &buffer);
        const result = try allocator.alloc(Range, pieces.len);
        @memcpy(result, pieces);
        return result;
    }

    pub fn splitByMonth(self: Range, allocator: std.mem.Allocator) core.Error![]Range {
        var count: usize = 0;
        try core.checkStatus(c.nepdate_range_split_by_month(self.cValue(), null, 0, &count));
        const result = try allocator.alloc(Range, count);
        errdefer allocator.free(result);
        var written: usize = 0;
        try core.checkStatus(c.nepdate_range_split_by_month(
            self.cValue(),
            @ptrCast(result.ptr),
            result.len,
            &written,
        ));
        return result[0..written];
    }

    pub fn splitByFiscalQuarter(self: Range, allocator: std.mem.Allocator) core.Error![]Range {
        var count: usize = 0;
        try core.checkStatus(c.nepdate_range_split_by_fiscal_quarter(self.cValue(), null, 0, &count));
        const result = try allocator.alloc(Range, count);
        errdefer allocator.free(result);
        var written: usize = 0;
        try core.checkStatus(c.nepdate_range_split_by_fiscal_quarter(
            self.cValue(),
            @ptrCast(result.ptr),
            result.len,
            &written,
        ));
        return result[0..written];
    }

    pub fn datesWithInterval(self: Range, interval: i32) core.Error!DayIterator {
        var out: c.range_day_cursor = undefined;
        try core.checkStatus(c.nepdate_range_dates_with_interval(self.cValue(), interval, &out));
        return .{ .cursor = out };
    }

    pub fn workingDays(self: Range, exclude_sunday: bool) core.Error!DayIterator {
        var out: c.range_day_cursor = undefined;
        try core.checkStatus(c.nepdate_range_working_days(self.cValue(), exclude_sunday, &out));
        return .{ .cursor = out };
    }

    pub fn weekendDays(self: Range, include_sunday: bool) core.Error!DayIterator {
        var out: c.range_day_cursor = undefined;
        try core.checkStatus(c.nepdate_range_weekend_days(self.cValue(), include_sunday, &out));
        return .{ .cursor = out };
    }

    pub fn iterator(self: Range) Iterator {
        var out: c.range_iterator = undefined;
        _ = c.nepdate_range_begin(self.cValue(), &out);
        return .{ .cursor = out };
    }

    pub fn days(self: Range) Iterator {
        return self.iterator();
    }

    pub fn eql(self: Range, other: Range) bool {
        var out: bool = undefined;
        _ = c.nepdate_range_equal(self.cValue(), other.cValue(), &out);
        return out;
    }

    pub fn hash(self: Range) u64 {
        const a: u32 = @bitCast(self.start.value.value);
        const b: u32 = @bitCast(self.end.value.value);
        return (@as(u64, a) << 32) | b;
    }

    /// `start - end` in the default display.
    pub fn formatAlloc(self: Range, allocator: std.mem.Allocator) core.Error![:0]u8 {
        const needed = c.nepdate_range_format(self.cValue(), null, 0);
        if (needed == 0) return error.InvalidDate;
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_range_format(self.cValue(), buffer.ptr, needed + 1);
        return buffer;
    }

    pub fn formatShortAlloc(
        self: Range,
        allocator: std.mem.Allocator,
        order: core.Order,
        separator: core.Separator,
        lang: core.Lang,
    ) core.Error![:0]u8 {
        const needed = c.nepdate_range_format_short(
            self.cValue(),
            @fromBackingInt(@intCast(@backingInt(order))),
            @fromBackingInt(@intCast(@backingInt(separator))),
            @fromBackingInt(@intCast(@backingInt(lang))),
            null,
            0,
        );
        if (needed == 0) return error.InvalidDate;
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_range_format_short(
            self.cValue(),
            @fromBackingInt(@intCast(@backingInt(order))),
            @fromBackingInt(@intCast(@backingInt(separator))),
            @fromBackingInt(@intCast(@backingInt(lang))),
            buffer.ptr,
            needed + 1,
        );
        return buffer;
    }

    pub fn write(self: Range, buffer: []u8) core.Error![]const u8 {
        var temporary: [64]u8 = undefined;
        const needed = c.nepdate_range_format(self.cValue(), &temporary, temporary.len);
        if (needed == 0) return error.InvalidDate;
        if (needed > buffer.len) return error.NoSpace;
        @memcpy(buffer[0..needed], temporary[0..needed]);
        return buffer[0..needed];
    }

    pub fn format(self: Range, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        var buffer: [64]u8 = undefined;
        const needed = c.nepdate_range_format(self.cValue(), &buffer, buffer.len);
        if (needed == 0 or needed > buffer.len) return error.WriteFailed;
        try writer.writeAll(buffer[0..needed]);
    }

    fn cValue(self: Range) c.range {
        return .{ .start = self.start.value, .end = self.end.value };
    }
};

pub const Iterator = struct {
    cursor: c.range_iterator,

    pub fn next(self: *Iterator) ?core.Date {
        var out: c.date = undefined;
        if (!c.nepdate_range_next(&self.cursor, &out)) return null;
        return .{ .value = out };
    }
};

pub const DayIterator = struct {
    cursor: c.range_day_cursor,

    pub fn next(self: *DayIterator) ?core.Date {
        var out: c.date = undefined;
        if (!c.nepdate_range_day_next(&self.cursor, &out)) return null;
        return .{ .value = out };
    }
};

test "range basics" {
    const a = try core.Date.fromBs(2081, 4, 10);
    const b = try core.Date.fromBs(2081, 4, 20);
    const span = try Range.of(a, b);
    try std.testing.expectEqual(@as(i32, 11), span.length());
    try std.testing.expect(span.contains(a));
    try std.testing.expect(span.contains(b));

    var iterator = span.iterator();
    var count: i32 = 0;
    while (iterator.next()) |_| count += 1;
    try std.testing.expectEqual(@as(i32, 11), count);
}
