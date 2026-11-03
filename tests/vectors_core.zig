const std = @import("std");
const core = @import("nepdate");
const common = @import("common.zig");
const testing = std.testing;

fn expectOptionalDate(expected: []const u8, value: core.Error!core.Date) !void {
    if (std.mem.eql(u8, expected, "ERR")) {
        try testing.expectError(error.OutOfRange, value);
    } else {
        try common.expectDate(expected, try value);
    }
}

test "month boundaries: every month start and end converts both ways" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/month-boundaries.csv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const bs = try common.date(row.get("bs"));
        const ad = try common.gregorian(row.get("ad"));
        try common.expectGregorian(row.get("ad"), bs.toGregorian());
        try common.expectDate(row.get("bs"), try core.Date.fromGregorian(ad.year, ad.month, ad.day));
        try common.expectDate(row.get("bs"), bs);
        try testing.expectEqualStrings(row.get("weekday"), bs.dayOfWeek().englishName());
        try testing.expectEqual(@as(u8, @intCast(try row.int("month_length"))), bs.monthLength());
        count += 1;
    }
    try testing.expectEqual(@as(usize, 7176), count);
}

test "dates golden: conversion, names, long and short forms, fiscal dates" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/dates.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const bs = try common.date(row.get("bs"));
        try common.expectGregorian(row.get("ad"), bs.toGregorian());
        try testing.expectEqualStrings(row.get("weekday"), bs.dayOfWeek().englishName());
        try testing.expectEqual(@as(u16, @intCast(try row.int("day_of_year"))), bs.dayOfYear());
        try testing.expectEqual(@as(u8, @intCast(try row.int("month_length"))), bs.monthLength());

        var default_buffer: [32]u8 = undefined;
        try testing.expectEqualStrings(row.get("to_string"), try bs.write(&default_buffer));

        const unicode = try bs.shortAlloc(testing.allocator, .{ .lang = .ne });
        defer testing.allocator.free(unicode);
        try testing.expectEqualStrings(row.get("unicode"), unicode);

        const long_en = try bs.longAlloc(testing.allocator, .{});
        defer testing.allocator.free(long_en);
        try testing.expectEqualStrings(row.get("long_en"), long_en);

        const long_en_weekday = try bs.longAlloc(testing.allocator, .{ .weekday = true });
        defer testing.allocator.free(long_en_weekday);
        try testing.expectEqualStrings(row.get("long_en_weekday"), long_en_weekday);

        const long_ne = try bs.longAlloc(testing.allocator, .{ .lang = .ne });
        defer testing.allocator.free(long_ne);
        try testing.expectEqualStrings(row.get("long_ne"), long_ne);

        const long_ne_weekday = try bs.longAlloc(testing.allocator, .{ .weekday = true, .lang = .ne });
        defer testing.allocator.free(long_ne_weekday);
        try testing.expectEqualStrings(row.get("long_ne_weekday"), long_ne_weekday);

        const dmy = try bs.shortAlloc(testing.allocator, .{
            .order = .dmy,
            .separator = .dash,
            .pad = false,
        });
        defer testing.allocator.free(dmy);
        try testing.expectEqualStrings(row.get("dmy_dash_nopad"), dmy);

        const fy = core.FiscalYear.containing(bs);
        try expectOptionalDate(row.get("fy_start"), fy.start());
        try expectOptionalDate(row.get("fy_end"), fy.end());
        try expectOptionalDate(row.get("quarter_start"), fy.quarterStart(bs.quarter()));
        try expectOptionalDate(row.get("quarter_end"), fy.quarterEnd(bs.quarter()));
        count += 1;
    }
    try testing.expectEqual(@as(usize, 1018), count);
}

test "year lengths" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/year-length.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const year = try row.int("bs_year");
        const date = try core.Date.fromBs(year, 1, 1);
        try testing.expectEqual(@as(u16, @intCast(try row.int("year_length"))), date.yearLength());
        count += 1;
    }
    try testing.expectEqual(@as(usize, 299), count);
}

test "day differences in both directions" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/day-diff.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const a = try common.date(row.get("a"));
        const b = try common.date(row.get("b"));
        try testing.expectEqual(@as(i32, @intCast(try row.int("days_until"))), a.daysUntil(b));
        try testing.expectEqual(@as(i32, @intCast(try row.int("operator_minus"))), a.minus(b).total_days);
        count += 1;
    }
    try testing.expectEqual(@as(usize, 16), count);
}

test "YYYYMMDD integers, including the wide negative rows" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/ymd-int.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        if (std.mem.eql(u8, row.get("kind"), "date")) {
            const date = try common.date(row.get("input"));
            try testing.expectEqual(try row.int("ymd"), date.ymd());
            try common.expectDate(row.get("result"), date);
        } else {
            const value = try row.int("ymd");
            if (std.mem.eql(u8, row.get("result"), "ERR")) {
                if (core.Date.fromYmd(value)) |_| {
                    return error.ExpectedError;
                } else |_| {}
            } else {
                try common.expectDate(row.get("result"), try core.Date.fromYmd(value));
            }
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 14), count);
}

test "bulk conversion preserves order and is all or nothing" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/bulk.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const operation = row.get("operation");
        const input = row.get("input");
        const expected = row.get("output");
        if (std.mem.eql(u8, operation, "to_nepali_dates") or std.mem.eql(u8, operation, "batch_to_nepali_dates")) {
            var gregorians: [16]core.Gregorian = undefined;
            var dates: [16]core.Date = undefined;
            const inputs = try splitDates(input, &gregorians);
            if (std.mem.eql(u8, expected, "ERR")) {
                try testing.expectError(error.OutOfRange, core.toNepaliDates(inputs, &dates));
            } else {
                const result = try core.toNepaliDates(inputs, &dates);
                try expectDateList(expected, result);
            }
        } else if (std.mem.eql(u8, operation, "to_english_dates_from_strings")) {
            var texts: [16][]const u8 = undefined;
            var gregorians: [16]core.Gregorian = undefined;
            const n = try splitTexts(input, &texts);
            if (std.mem.eql(u8, expected, "ERR")) {
                try testing.expectError(error.InvalidDay, core.parseAll(texts[0..n], &gregorians));
            } else {
                const result = try core.parseAll(texts[0..n], &gregorians);
                try expectGregorianList(expected, result);
            }
        } else if (std.mem.eql(u8, operation, "to_english_dates_from_dates") or std.mem.eql(u8, operation, "batch_to_english_dates")) {
            var dates: [16]core.Date = undefined;
            var gregorians: [16]core.Gregorian = undefined;
            const input_dates = try splitNepaliDates(input, &dates);
            const result = try core.toEnglishDates(input_dates, &gregorians);
            try expectGregorianList(expected, result);
        } else {
            return error.UnknownOperation;
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 6), count);
}

test "serialization: canonical JSON string, read back, null rejected" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/serialization.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const kind = row.get("kind");
        const input = row.get("input");
        if (std.mem.eql(u8, kind, "write") or std.mem.eql(u8, kind, "roundtrip")) {
            const date = try common.date(input);
            const json = try date.toJsonAlloc(testing.allocator);
            defer testing.allocator.free(json);
            var quoted: [64]u8 = undefined;
            try testing.expectEqualStrings(row.get("json"), try std.fmt.bufPrint(&quoted, "\"{s}\"", .{json}));
            try common.expectDate(input, date);
        } else if (std.mem.eql(u8, kind, "read")) {
            if (std.mem.eql(u8, input, "null")) {
                try testing.expectError(error.Unrecognized, core.Date.fromJson(input));
            } else if (std.mem.eql(u8, row.get("result"), "ERR")) {
                try testing.expectError(error.InvalidDay, core.Date.fromJson(input));
            } else {
                try common.expectDate(row.get("result"), try core.Date.fromJson(input));
            }
        } else {
            return error.UnknownKind;
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 11), count);
}

fn splitDates(text: []const u8, out: *[16]core.Gregorian) ![]const core.Gregorian {
    var count: usize = 0;
    var parts = std.mem.splitScalar(u8, text, ';');
    while (parts.next()) |part| : (count += 1) out[count] = try common.gregorian(part);
    return out[0..count];
}

fn splitNepaliDates(text: []const u8, out: *[16]core.Date) ![]const core.Date {
    var count: usize = 0;
    var parts = std.mem.splitScalar(u8, text, ';');
    while (parts.next()) |part| : (count += 1) out[count] = try common.date(part);
    return out[0..count];
}

fn splitTexts(text: []const u8, out: *[16][]const u8) !usize {
    var count: usize = 0;
    var parts = std.mem.splitScalar(u8, text, ';');
    while (parts.next()) |part| : (count += 1) out[count] = part;
    return count;
}

fn expectDateList(expected: []const u8, dates: []const core.Date) !void {
    var buffer: [512]u8 = undefined;
    var stream = std.Io.Writer.fixed(&buffer);
    for (dates, 0..) |date, i| {
        if (i != 0) try stream.writeAll(";");
        try stream.print("{d:0>4}-{d:0>2}-{d:0>2}", .{
            @as(u32, @intCast(date.year())),
            @as(u32, @intCast(date.monthNumber())),
            @as(u32, @intCast(date.day())),
        });
    }
    try testing.expectEqualStrings(expected, stream.buffered());
}

fn expectGregorianList(expected: []const u8, dates: []const core.Gregorian) !void {
    var buffer: [512]u8 = undefined;
    var stream = std.Io.Writer.fixed(&buffer);
    for (dates, 0..) |date, i| {
        if (i != 0) try stream.writeAll(";");
        try stream.print("{d:0>4}-{d:0>2}-{d:0>2}", .{
            @as(u32, @intCast(date.year)),
            @as(u32, @intCast(date.month)),
            @as(u32, @intCast(date.day)),
        });
    }
    try testing.expectEqualStrings(expected, stream.buffered());
}
