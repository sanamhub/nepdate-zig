const std = @import("std");
const core = @import("nepdate");
const common = @import("common.zig");
const testing = std.testing;

fn expectedParseError(text: []const u8) core.Error!void {
    if (std.mem.eql(u8, text, "InvalidCharacter")) return error.InvalidCharacter;
    if (std.mem.eql(u8, text, "WrongGroupCount")) return error.WrongGroupCount;
    if (std.mem.eql(u8, text, "NumberTooLong")) return error.NumberTooLong;
    if (std.mem.eql(u8, text, "Ambiguous")) return error.Ambiguous;
    if (std.mem.eql(u8, text, "Unrecognized")) return error.Unrecognized;
    if (std.mem.eql(u8, text, "OutOfRange")) return error.OutOfRange;
    if (std.mem.eql(u8, text, "InvalidMonth")) return error.InvalidMonth;
    if (std.mem.eql(u8, text, "InvalidDay")) return error.InvalidDay;
    return error.UnknownExpectedError;
}

fn expectParse(input: []const u8, expected: []const u8, result: core.Error!core.Date) !void {
    if (std.mem.eql(u8, expected, "ERR")) {
        if (result) |_| {
            std.debug.print("unexpected success for {s}\n", .{input});
            return error.ExpectedParseError;
        } else |_| {}
    } else if (std.mem.startsWith(u8, expected, "ERR:")) {
        const wanted = expected[4..];
        if (result) |_| {
            return error.ExpectedParseError;
        } else |actual| {
            var kind_buffer: [32]u8 = undefined;
            const actual_name = try std.fmt.bufPrint(&kind_buffer, "{s}", .{@errorName(actual)});
            try testing.expectEqualStrings(wanted, actual_name);
        }
    } else {
        try common.expectDate(expected, try result);
    }
}

test "strict and lenient parse vectors, including the error kinds" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/parse.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        try expectParse(row.get("input"), row.get("strict"), core.Date.parse(row.get("input")));
        try expectParse(row.get("input"), row.get("lenient"), core.Date.parseLenient(row.get("input")));
        count += 1;
    }
    try testing.expectEqual(@as(usize, 69), count);
}

test "C# golden strict parse rows" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/parse.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        // D-05: C# does not accept Devanagari digits, while the port does.
        if (std.mem.eql(u8, row.get("strict"), "ERR") and hasNonAscii(row.get("input"))) {
            count += 1;
            continue;
        }
        try expectParse(row.get("input"), row.get("strict"), core.Date.parse(row.get("input")));
        count += 1;
    }
    try testing.expectEqual(@as(usize, 42), count);
}

fn hasNonAscii(text: []const u8) bool {
    for (text) |byte| if (byte >= 0x80) return true;
    return false;
}

test "custom format patterns, with the D-04 month abbreviation fix" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/format-pattern.tsv"));
    defer t.deinit();
    var count: usize = 0;
    var skipped: usize = 0;
    for (t.rows) |row| {
        const date = try common.date(row.get("bs"));
        const pattern = row.get("pattern");
        const has_three = std.mem.indexOf(u8, pattern, "MMM") != null;
        const has_four = std.mem.indexOf(u8, pattern, "MMMM") != null;
        if (has_three and !has_four and (date.monthNumber() == 3 or date.monthNumber() == 6)) {
            skipped += 1;
            continue;
        }
        const text = try date.formatAlloc(testing.allocator, pattern, .en);
        defer testing.allocator.free(text);
        try testing.expectEqualStrings(row.get("result"), text);
        count += 1;
    }
    try testing.expectEqual(@as(usize, 452), count + skipped);
}

test "short matrix and bounded formatting" {
    var t = try common.load(testing.allocator, @embedFile("../shared/spec/vectors/csharp-golden/format-matrix.tsv"));
    defer t.deinit();
    var count: usize = 0;
    for (t.rows) |row| {
        const date = try common.date(row.get("bs"));
        if (std.mem.eql(u8, row.get("kind"), "short")) {
            const order = parseOrder(row.get("order"));
            const separator = parseSeparator(row.get("separator"));
            const lang: core.Lang = if (std.mem.eql(u8, row.get("lang"), "ne")) .ne else .en;
            const text = try date.shortAlloc(testing.allocator, .{
                .order = order,
                .separator = separator,
                .pad = std.mem.eql(u8, row.get("pad"), "true"),
                .lang = lang,
            });
            defer testing.allocator.free(text);
            try testing.expectEqualStrings(row.get("result"), text);
        } else {
            const capacity = try row.int("capacity");
            var buffer: [256]u8 = undefined;
            const format = row.get("format");
            const pattern = if (std.mem.eql(u8, format, "default")) "" else format;
            const result = date.formatTo(buffer[0..@intCast(capacity)], pattern, .en);
            if (std.mem.eql(u8, row.get("result"), "ERR")) {
                try testing.expectError(error.NoSpace, result);
            } else {
                try testing.expectEqualStrings(row.get("result"), try result);
            }
        }
        count += 1;
    }
    try testing.expectEqual(@as(usize, 102), count);
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
