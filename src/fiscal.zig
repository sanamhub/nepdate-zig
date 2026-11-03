//! Fiscal years and fiscal quarters, 1 Shrawan to the last day of Ashad.

const std = @import("std");
const core = @import("nepdate.zig");
const c = @import("c.zig");

/// A Nepali fiscal year, named by the BS year in which it starts (1 Shrawan).
pub const FiscalYear = struct {
    year: i32,

    /// The fiscal year that contains `date`.
    pub fn containing(date: core.Date) FiscalYear {
        var out: c_int = undefined;
        _ = c.nepdate_fiscal_year_of(date.value, &out);
        return .{ .year = out };
    }

    /// A fiscal year by its starting BS year. The start must be a supported date.
    pub fn init(year: i64) core.Error!FiscalYear {
        if (year < std.math.minInt(i32) or year > std.math.maxInt(i32)) return error.OutOfRange;
        const result = FiscalYear{ .year = @intCast(year) };
        _ = try result.start();
        _ = try result.end();
        return result;
    }

    pub fn start(self: FiscalYear) core.Error!core.Date {
        var out: c.date = undefined;
        try core.checkStatus(c.nepdate_fiscal_year_start(self.year, &out));
        return .{ .value = out };
    }

    pub fn end(self: FiscalYear) core.Error!core.Date {
        var out: c.date = undefined;
        try core.checkStatus(c.nepdate_fiscal_year_end(self.year, &out));
        return .{ .value = out };
    }

    /// The whole fiscal year as an inclusive range.
    pub fn range(self: FiscalYear) core.Error!core.Range {
        var out: c.range = undefined;
        try core.checkStatus(c.nepdate_range_of_fiscal_year(self.year, &out));
        return .{ .start = .{ .value = out.start }, .end = .{ .value = out.end } };
    }

    /// The first day of `quarter` in this fiscal year.
    pub fn quarterStart(self: FiscalYear, quarter: core.Quarter) core.Error!core.Date {
        var out: c.date = undefined;
        try core.checkStatus(c.nepdate_quarter_start(
            self.year,
            @fromBackingInt(@intCast(@backingInt(quarter))),
            &out,
        ));
        return .{ .value = out };
    }

    /// The last day of `quarter` in this fiscal year.
    pub fn quarterEnd(self: FiscalYear, quarter: core.Quarter) core.Error!core.Date {
        var out: c.date = undefined;
        try core.checkStatus(c.nepdate_quarter_end(
            self.year,
            @fromBackingInt(@intCast(@backingInt(quarter))),
            &out,
        ));
        return .{ .value = out };
    }

    /// The inclusive range of `quarter`.
    pub fn quarterRange(self: FiscalYear, quarter: core.Quarter) core.Error!core.Range {
        return core.Range.of(try self.quarterStart(quarter), try self.quarterEnd(quarter));
    }

    /// The label, for example `2081/82`, in English or Devanagari digits.
    pub fn labelAlloc(
        self: FiscalYear,
        allocator: std.mem.Allocator,
        lang: core.Lang,
    ) core.Error![:0]u8 {
        const needed = c.nepdate_fiscal_year_label(
            self.year,
            @fromBackingInt(@intCast(@backingInt(lang))),
            null,
            0,
        );
        const buffer = try allocator.allocSentinel(u8, needed, 0);
        errdefer allocator.free(buffer);
        _ = c.nepdate_fiscal_year_label(
            self.year,
            @fromBackingInt(@intCast(@backingInt(lang))),
            buffer.ptr,
            needed + 1,
        );
        return buffer;
    }

    /// Writes the label into a caller buffer of at least 39 bytes.
    pub fn label(
        self: FiscalYear,
        buffer: []u8,
        lang: core.Lang,
    ) core.Error![]const u8 {
        var temporary: [64]u8 = undefined;
        const needed = c.nepdate_fiscal_year_label(
            self.year,
            @fromBackingInt(@intCast(@backingInt(lang))),
            &temporary,
            temporary.len,
        );
        if (needed > buffer.len) return error.NoSpace;
        @memcpy(buffer[0..needed], temporary[0..needed]);
        return buffer[0..needed];
    }

    pub fn eql(self: FiscalYear, other: FiscalYear) bool {
        return self.year == other.year;
    }

    pub fn compare(self: FiscalYear, other: FiscalYear) std.math.Order {
        return std.math.order(self.year, other.year);
    }
};

test "fiscal year basics" {
    const date = try core.Date.fromBs(2082, 1, 15);
    const fy = FiscalYear.containing(date);
    try std.testing.expectEqual(@as(i32, 2081), fy.year);
    var label_buffer: [39]u8 = undefined;
    try std.testing.expectEqualStrings("2081/82", try fy.label(&label_buffer, .en));
}
