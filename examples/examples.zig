const std = @import("std");
const nepdate = @import("nepdate");
const patro = @import("nepdate_patro");
const testing = std.testing;

test "README: quick start" {
    const date = try nepdate.Date.fromBs(2081, 4, 15);
    var buffer: [32]u8 = undefined;
    try testing.expectEqualStrings("2081/04/15", try date.write(&buffer));
    try expectJson("2081-04-15", date);
    const text = try date.longAlloc(testing.allocator, .{ .weekday = true });
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("Tuesday, Shrawan 15, 2081", text);
}

test "README: dates" {
    const date = try nepdate.Date.fromBs(2081, 4, 32);
    try testing.expectEqual(@as(i32, 2081), date.year());
    try testing.expectEqual(@as(u8, 4), date.monthNumber());
    try testing.expectEqual(@as(u8, 32), date.day());
    try testing.expectEqual(nepdate.Weekday.friday, date.dayOfWeek());
    try testing.expectEqual(@as(u16, 126), date.dayOfYear());
    try testing.expectEqual(@as(u8, 32), date.monthLength());
    try testing.expectEqual(@as(u16, 366), date.yearLength());
    var buffer: [32]u8 = undefined;
    try testing.expectEqualStrings("1901/01/01", try nepdate.Date.min.write(&buffer));
    try testing.expectEqualStrings("2199/12/30", try nepdate.Date.max.write(&buffer));
}

test "README: conversion and serialization" {
    try expectJson("2081-04-15", try nepdate.Date.fromGregorian(2024, 7, 30));
    try expectJson("2081-04-15", try nepdate.Date.fromYmd(20810415));
    try testing.expectEqual(@as(i64, 20810415), (try nepdate.Date.fromBs(2081, 4, 15)).ymd());
    var ad_buffer: [16]u8 = undefined;
    const ad = (try nepdate.Date.fromBs(2081, 4, 15)).englishDate();
    try testing.expectEqualStrings("2024-07-30", try std.fmt.bufPrint(&ad_buffer, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(ad.year)),
        @as(u32, @intCast(ad.month)),
        @as(u32, @intCast(ad.day)),
    }));
}

test "README: batch conversion" {
    var nepali_out: [1]nepdate.Date = undefined;
    const dates = try nepdate.toNepaliDates(&.{.{ .year = 2024, .month = 7, .day = 30 }}, &nepali_out);
    try testing.expectEqual(@as(u8, 4), dates[0].monthNumber());
    var bs = [1]nepdate.Date{try nepdate.Date.fromBs(2081, 4, 15)};
    var out: [1]nepdate.Gregorian = undefined;
    const result = try nepdate.toEnglishDates(&bs, &out);
    try testing.expectEqual(@as(i32, 2024), result[0].year);
    _ = &bs;
}

test "README: arithmetic" {
    const date = try nepdate.Date.fromBs(2081, 4, 32);
    try expectJson("2081-05-30", try date.addDays(30));
    try expectJson("2081-06-30", try date.addMonths(2, .clamp));
    try expectJson("2081-07-02", try date.addMonths(2, .spill));
    try testing.expectEqual(@as(i32, 1), (try nepdate.Date.fromBs(2081, 4, 15)).daysUntil(try nepdate.Date.fromBs(2081, 4, 16)));
    try testing.expectEqual(@as(i32, 1), (try nepdate.Date.fromBs(2081, 4, 16)).minus(try nepdate.Date.fromBs(2081, 4, 15)).total_days);
}

test "README: formatting" {
    const date = try nepdate.Date.fromBs(2081, 4, 15);
    var formatted: [16]u8 = undefined;
    var stream = std.Io.Writer.fixed(&formatted);
    try stream.print("{f}", .{date});
    try testing.expectEqualStrings("2081/04/15", stream.buffered());
    const short = try date.shortAlloc(testing.allocator, .{ .order = .dmy, .separator = .dash });
    defer testing.allocator.free(short);
    try testing.expectEqualStrings("15-04-2081", short);
    const unicode = try date.shortAlloc(testing.allocator, .{ .lang = .ne });
    defer testing.allocator.free(unicode);
    try testing.expectEqualStrings("२०८१/०४/१५", unicode);
    const long = try date.longAlloc(testing.allocator, .{});
    defer testing.allocator.free(long);
    try testing.expectEqualStrings("Shrawan 15, 2081", long);
    const pattern = try date.formatAlloc(testing.allocator, "MMMM d, yyyy", .en);
    defer testing.allocator.free(pattern);
    try testing.expectEqualStrings("Shrawan 15, 2081", pattern);
}

test "README: parsing" {
    try expectJson("2081-04-15", try nepdate.Date.parse("2081/04/15"));
    try expectJson("2081-04-15", try nepdate.Date.parse("२०८१/०४/१५"));
    try expectJson("2081-04-15", try nepdate.Date.parseLenient("15 Shrawan 2081 B.S."));
    try testing.expectEqual(@as(?nepdate.Date, null), nepdate.Date.tryParse("2081/13/01"));
    try testing.expectEqual(@as(?nepdate.Date, null), nepdate.Date.tryParseLenient("15 Foo 2081"));
}

test "README: ranges" {
    const range = try nepdate.Range.of(
        try nepdate.Date.fromBs(2081, 4, 10),
        try nepdate.Date.fromBs(2081, 4, 20),
    );
    try testing.expectEqual(@as(i32, 11), range.length());
    try testing.expect(range.contains(try nepdate.Date.fromBs(2081, 4, 15)));
    const text = try range.formatAlloc(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("2081/04/10 - 2081/04/20", text);
    var formatted: [64]u8 = undefined;
    var stream = std.Io.Writer.fixed(&formatted);
    try stream.print("{f}", .{range});
    try testing.expectEqualStrings("2081/04/10 - 2081/04/20", stream.buffered());
}

test "README: fiscal year" {
    const date = try nepdate.Date.fromBs(2082, 1, 15);
    const fy = nepdate.FiscalYear.containing(date);
    try testing.expectEqual(@as(i32, 2081), fy.year);
    var buffer: [39]u8 = undefined;
    try testing.expectEqualStrings("2081/82", try fy.label(&buffer, .en));
    const quarter = try fy.quarterRange(.q4);
    try expectJson("2082-01-01", quarter.start);
}

test "README: today" {
    const instant: i64 = 1722364200; // 2024-07-30 18:30 UTC
    try expectJson("2081-04-16", try nepdate.Date.todayNepal(instant));
    try expectJson("2081-04-15", try nepdate.Date.today(0, instant));
    try testing.expect((try nepdate.Date.fromBs(2081, 4, 16)).isToday(nepdate.nepal_offset_minutes, instant));
}

test "README: patro" {
    var buffer: [8]patro.Event = undefined;
    const info = try patro.infoInto(try nepdate.Date.fromBs(2081, 1, 1), &buffer);
    try testing.expectEqualStrings("Panchami", info.tithiEn());
    try testing.expect(info.is_public_holiday);
    try testing.expectEqualStrings("New Year", info.events[0].english);

    const coverage = patro.coverage();
    try testing.expectEqual(@as(i32, 2793), coverage.length());
}

fn expectJson(expected: []const u8, date: nepdate.Date) !void {
    const text = try date.toJsonAlloc(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}
