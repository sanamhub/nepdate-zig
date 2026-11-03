const std = @import("std");
const core = @import("nepdate");
const common = @import("common.zig");
const testing = std.testing;

test "add days: clamp at both data ends" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/add-days.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const date = try common.date(row.get("bs"));
        const days = try row.int("days");
        const result = date.addDays(@intCast(days));
        if (std.mem.eql(u8, row.get("result"), "ERR")) {
            try testing.expectError(error.OutOfRange, result);
        } else {
            try common.expectDate(row.get("result"), try result);
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 9162), count);
}

test "add months: clamp and spill" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/add-months.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const date = try common.date(row.get("bs"));
        const months = try row.int("months");
        const clamp = date.addMonths(@intCast(months), .clamp);
        if (std.mem.eql(u8, row.get("clamp"), "ERR")) {
            try testing.expectError(error.OutOfRange, clamp);
        } else {
            try common.expectDate(row.get("clamp"), try clamp);
        }
        const spill = date.addMonths(@intCast(months), .spill);
        if (std.mem.eql(u8, row.get("overflow"), "ERR")) {
            try testing.expectError(error.OutOfRange, spill);
        } else {
            try common.expectDate(row.get("overflow"), try spill);
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 10180), count);
}

test "add years equals add months times twelve" {
    const date = try core.Date.fromBs(2081, 4, 32);
    try common.expectDate("2082-04-31", try date.addYears(1, .clamp));
    try common.expectDate("2080-04-32", try date.addYears(-1, .clamp));
    try common.expectDate("2082-04-31", try date.addMonths(12, .clamp));
}

test "integer extremes do not wrap" {
    const date = try core.Date.fromBs(2081, 4, 15);
    try testing.expectError(error.OutOfRange, date.addDays(std.math.maxInt(i32)));
    try testing.expectError(error.OutOfRange, date.addDays(std.math.minInt(i32)));
    try testing.expectError(error.OutOfRange, date.addMonths(std.math.maxInt(i32), .clamp));
    try testing.expectError(error.OutOfRange, date.addYears(std.math.maxInt(i32), .clamp));
    try testing.expectError(error.OutOfRange, core.Date.fromYmd(std.math.maxInt(i64)));
    try testing.expectError(error.OutOfRange, core.Date.fromBs(std.math.maxInt(i64), 1, 1));

    const last = core.Date.max;
    try testing.expectError(error.OutOfRange, core.Range.fromDayCount(last, std.math.maxInt(i32)));
    var one = try core.Range.single(last).datesWithInterval(std.math.maxInt(i32));
    try testing.expect(one.next().?.eql(last));
    try testing.expectEqual(@as(?core.Date, null), one.next());
}

test "clocks are explicit" {
    const instant: i64 = 1722364200; // 2024-07-30 18:30 UTC
    try common.expectDate("2081-04-16", try core.Date.todayNepal(instant));
    try common.expectDate("2081-04-16", try core.Date.todayIn(.nepal, instant));
    try common.expectDate("2081-04-15", try core.Date.today(0, instant));
    try common.expectDate("2081-04-15", try core.Date.todayIn(.utc, instant));
    try common.expectDate("2081-04-15", try core.Date.fromUnix(instant, 0));

    const today = try core.Date.fromBs(2081, 4, 16);
    try testing.expect(today.isToday(core.nepal_offset_minutes, instant));
    try testing.expect((try core.Date.fromBs(2081, 4, 15)).isYesterday(core.nepal_offset_minutes, instant));
    try testing.expect((try core.Date.fromBs(2081, 4, 17)).isTomorrow(core.nepal_offset_minutes, instant));
    try testing.expectError(error.OutOfRange, core.Date.today(0, std.math.maxInt(i64)));
}
