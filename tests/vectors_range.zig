const std = @import("std");
const core = @import("nepdate");
const common = @import("common.zig");
const testing = std.testing;

fn expectAnyError(result: anytype) !void {
    if (result) |_| return error.ExpectedError else |_| {}
}

fn parseRange(text: []const u8) !core.Range {
    const separator = std.mem.indexOf(u8, text, "..") orelse return error.BadRange;
    return core.Range.of(
        try common.date(text[0..separator]),
        try common.date(text[separator + 2 ..]),
    );
}

fn expectRange(expected: []const u8, actual: core.Range) !void {
    try common.expectDate(expected[0..10], actual.start);
    try common.expectDate(expected[12..], actual.end);
}

fn expectRangeList(expected: []const u8, actual: []const core.Range) !void {
    if (std.mem.eql(u8, expected, "none")) {
        try testing.expectEqual(@as(usize, 0), actual.len);
        return;
    }
    var parts = std.mem.splitScalar(u8, expected, ';');
    var i: usize = 0;
    while (parts.next()) |part| : (i += 1) {
        try testing.expect(i < actual.len);
        try expectRange(part, actual[i]);
    }
    try testing.expectEqual(i, actual.len);
}

fn expectDateList(expected: []const u8, iterator_value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var stream = std.Io.Writer.fixed(&buffer);
    var count: usize = 0;
    var iterator = iterator_value;
    while (iterator.next()) |date| {
        if (count != 0) try stream.writeAll(";");
        try stream.print("{d:0>4}-{d:0>2}-{d:0>2}", .{
            @as(u32, @intCast(date.year())),
            @as(u32, @intCast(date.monthNumber())),
            @as(u32, @intCast(date.day())),
        });
        count += 1;
    }
    if (std.mem.eql(u8, expected, "none")) {
        try testing.expectEqual(@as(usize, 0), count);
        return;
    }
    try testing.expectEqualStrings(expected, stream.buffered());
}

test "range operations" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/ranges.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const operation = row.get("operation");
        if (std.mem.eql(u8, operation, "construct")) {
            const start = common.date(row.get("start"));
            const end = common.date(row.get("end"));
            if (std.mem.eql(u8, row.get("result"), "ERR")) {
                if (start) |a| {
                    if (end) |b| {
                        try testing.expectError(error.OutOfRange, core.Range.of(a, b));
                    } else |_| {}
                } else |_| {}
            } else {
                try expectRange(row.get("result"), try core.Range.of(try start, try end));
            }
        } else {
            const start = try common.date(row.get("start"));
            const end = try common.date(row.get("end"));
            const range = try core.Range.of(start, end);
            if (std.mem.eql(u8, operation, "length")) {
                try testing.expectEqual(@as(i32, @intCast(try row.int("result"))), range.length());
            } else if (std.mem.eql(u8, operation, "contains_date")) {
                try testing.expectEqual(std.mem.eql(u8, row.get("result"), "true"), range.contains(try common.date(row.get("argument"))));
            } else if (std.mem.eql(u8, operation, "contains_range")) {
                try testing.expectEqual(std.mem.eql(u8, row.get("result"), "true"), range.containsRange(try parseRange(row.get("argument"))));
            } else if (std.mem.eql(u8, operation, "overlaps")) {
                try testing.expectEqual(std.mem.eql(u8, row.get("result"), "true"), range.overlaps(try parseRange(row.get("argument"))));
            } else if (std.mem.eql(u8, operation, "is_adjacent_to")) {
                try testing.expectEqual(std.mem.eql(u8, row.get("result"), "true"), range.isAdjacentTo(try parseRange(row.get("argument"))));
            } else if (std.mem.eql(u8, operation, "intersect")) {
                if (std.mem.eql(u8, row.get("result"), "none")) {
                    try testing.expectError(error.NoOverlap, range.intersect(try parseRange(row.get("argument"))));
                } else {
                    try expectRange(row.get("result"), try range.intersect(try parseRange(row.get("argument"))));
                }
            } else if (std.mem.eql(u8, operation, "union")) {
                try expectRange(row.get("result"), range.unionWith(try parseRange(row.get("argument"))));
            } else if (std.mem.eql(u8, operation, "except")) {
                var buffer: [2]core.Range = undefined;
                try expectRangeList(row.get("result"), try range.except(try parseRange(row.get("argument")), &buffer));
            } else if (std.mem.eql(u8, operation, "equals")) {
                try testing.expectEqual(std.mem.eql(u8, row.get("result"), "true"), range.eql(try parseRange(row.get("argument"))));
            } else if (std.mem.eql(u8, operation, "to_string")) {
                const text = try range.formatAlloc(testing.allocator);
                defer testing.allocator.free(text);
                try testing.expectEqualStrings(row.get("result"), text);
            } else if (std.mem.eql(u8, operation, "enumerate")) {
                try expectDateList(row.get("result"), range.iterator());
            } else {
                return error.UnknownOperation;
            }
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 54), count);
}

test "range factories" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/range-factories.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const factory = row.get("factory");
        const argument = row.get("argument");
        const result = row.get("result");
        if (std.mem.eql(u8, factory, "construct")) {
            const comma = std.mem.indexOfScalar(u8, argument, ',') orelse return error.BadRange;
            const first = try common.date(argument[0..comma]);
            const second = common.date(argument[comma + 1 ..]);
            if (std.mem.eql(u8, result, "ERR")) {
                if (second) |value| {
                    try testing.expectError(error.OutOfRange, core.Range.of(first, value));
                } else |_| {}
            } else {
                try expectRange(result, try core.Range.of(first, try second));
            }
        } else if (std.mem.eql(u8, factory, "single_day")) {
            if (std.mem.eql(u8, result, "ERR")) {
                if (common.date(argument)) |_| return error.ExpectedError else |_| {}
            } else {
                try expectRange(result, core.Range.single(try common.date(argument)));
            }
        } else if (std.mem.eql(u8, factory, "from_day_count")) {
            const comma = std.mem.indexOfScalar(u8, argument, ',') orelse return error.BadRange;
            const start = try common.date(argument[0..comma]);
            const days = try std.fmt.parseInt(i32, argument[comma + 1 ..], 10);
            if (std.mem.eql(u8, result, "ERR")) {
                try expectAnyError(core.Range.fromDayCount(start, days));
            } else {
                try expectRange(result, try core.Range.fromDayCount(start, days));
            }
        } else if (std.mem.eql(u8, factory, "for_month")) {
            const comma = std.mem.indexOfScalar(u8, argument, ',') orelse return error.BadRange;
            const year = try std.fmt.parseInt(i64, argument[0..comma], 10);
            const month = try std.fmt.parseInt(i64, argument[comma + 1 ..], 10);
            if (std.mem.eql(u8, result, "ERR")) {
                try expectAnyError(core.Range.forMonth(year, month));
            } else {
                try expectRange(result, try core.Range.forMonth(year, month));
            }
        } else if (std.mem.eql(u8, factory, "for_calendar_year")) {
            const year = try std.fmt.parseInt(i64, argument, 10);
            if (std.mem.eql(u8, result, "ERR")) {
                try expectAnyError(core.Range.forCalendarYear(year));
            } else {
                try expectRange(result, try core.Range.forCalendarYear(year));
            }
        } else if (std.mem.eql(u8, factory, "for_fiscal_year")) {
            const year = try std.fmt.parseInt(i64, argument, 10);
            if (std.mem.eql(u8, result, "ERR")) {
                try expectAnyError(core.Range.forFiscalYear(year));
            } else {
                try expectRange(result, try core.Range.forFiscalYear(year));
            }
        } else {
            return error.UnknownFactory;
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 27), count);
}

test "range splits at every month and fiscal quarter" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/range-splits.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const range = try core.Range.of(try common.date(row.get("start")), try common.date(row.get("end")));
        if (std.mem.eql(u8, row.get("operation"), "split_by_month")) {
            const pieces = try range.splitByMonth(testing.allocator);
            defer testing.allocator.free(pieces);
            try expectRangeList(row.get("result"), pieces);
        } else {
            const pieces = try range.splitByFiscalQuarter(testing.allocator);
            defer testing.allocator.free(pieces);
            try expectRangeList(row.get("result"), pieces);
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 9), count);
}

test "range day helpers at the data end" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/range-days.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const range = try core.Range.of(try common.date(row.get("start")), try common.date(row.get("end")));
        const operation = row.get("operation");
        if (std.mem.eql(u8, operation, "dates_with_interval")) {
            const interval = try row.int("argument");
            if (std.mem.eql(u8, row.get("result"), "ERR")) {
                try testing.expectError(error.OutOfRange, range.datesWithInterval(@intCast(interval)));
            } else {
                var iterator = try range.datesWithInterval(@intCast(interval));
                try expectDateList(row.get("result"), &iterator);
            }
        } else if (std.mem.eql(u8, operation, "working_days")) {
            var iterator = try range.workingDays(std.mem.eql(u8, row.get("argument"), "true"));
            try expectDateList(row.get("result"), &iterator);
        } else if (std.mem.eql(u8, operation, "weekend_days")) {
            var iterator = try range.weekendDays(std.mem.eql(u8, row.get("argument"), "true"));
            try expectDateList(row.get("result"), &iterator);
        } else {
            var iterator = range.iterator();
            try expectDateList(row.get("result"), &iterator);
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 18), count);
}

test "range string forms" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/range-format.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const start = common.date(row.get("start"));
        const end = common.date(row.get("end"));
        if (std.mem.eql(u8, row.get("result"), "ERR")) {
            if (start) |a| {
                if (end) |b| {
                    try testing.expectError(error.OutOfRange, core.Range.of(a, b));
                } else |_| {}
            } else |_| {}
        } else if (std.mem.eql(u8, row.get("kind"), "default")) {
            const range = try core.Range.of(try start, try end);
            const text = try range.formatAlloc(testing.allocator);
            defer testing.allocator.free(text);
            try testing.expectEqualStrings(row.get("result"), text);
        } else {
            const range = try core.Range.of(try start, try end);
            const text = try range.formatShortAlloc(
                testing.allocator,
                parseOrder(row.get("order")),
                parseSeparator(row.get("separator")),
                if (std.mem.eql(u8, row.get("lang"), "ne")) .ne else .en,
            );
            defer testing.allocator.free(text);
            try testing.expectEqualStrings(row.get("result"), text);
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 18), count);
}

fn parseOrder(text: []const u8) core.Order {
    if (std.mem.eql(u8, text, "Ymd")) return .ymd;
    if (std.mem.eql(u8, text, "Ydm")) return .ydm;
    if (std.mem.eql(u8, text, "Myd")) return .myd;
    if (std.mem.eql(u8, text, "Mdy")) return .mdy;
    if (std.mem.eql(u8, text, "Dym")) return .dym;
    return .dmy;
}

fn parseSeparator(text: []const u8) core.Separator {
    if (std.mem.eql(u8, text, "Backslash")) return .backslash;
    if (std.mem.eql(u8, text, "Dot")) return .dot;
    if (std.mem.eql(u8, text, "Underscore")) return .underscore;
    if (std.mem.eql(u8, text, "Dash")) return .dash;
    if (std.mem.eql(u8, text, "Space")) return .space;
    return .slash;
}
