const std = @import("std");

pub const Table = struct {
    allocator: std.mem.Allocator,
    headers: []const []const u8,
    rows: []Row,

    pub const Row = struct {
        headers: []const []const u8,
        fields: []const []const u8,

        pub fn get(self: Row, name: []const u8) []const u8 {
            for (self.headers, 0..) |header, i| {
                if (std.mem.eql(u8, header, name)) {
                    return if (i < self.fields.len) self.fields[i] else "";
                }
            }
            @panic("unknown vector column");
        }

        pub fn int(self: Row, name: []const u8) !i64 {
            return std.fmt.parseInt(i64, self.get(name), 10);
        }
    };

    pub fn load(allocator: std.mem.Allocator, content: []const u8) !Table {
        var headers: []const []const u8 = &.{};
        var rows: std.ArrayList(Row) = .empty;
        errdefer rows.deinit(allocator);
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |raw_line| {
            const line = std.mem.trimEnd(u8, raw_line, "\r");
            if (line.len == 0 or line[0] == '#') continue;
            const fields = try splitFields(allocator, line);
            if (headers.len == 0) {
                headers = fields;
                continue;
            }
            try rows.append(allocator, .{ .headers = headers, .fields = fields });
        }
        const result_rows = try rows.toOwnedSlice(allocator);
        return .{ .allocator = allocator, .headers = headers, .rows = result_rows };
    }

    pub fn deinit(self: *Table) void {
        for (self.rows) |row| self.allocator.free(row.fields);
        self.allocator.free(self.rows);
        self.allocator.free(self.headers);
    }
};

fn splitFields(allocator: std.mem.Allocator, line: []const u8) ![]const []const u8 {
    var fields: std.ArrayList([]const u8) = .empty;
    errdefer fields.deinit(allocator);
    const separator: u8 = if (std.mem.indexOfScalar(u8, line, '\t') != null) '\t' else ',';
    var parts = std.mem.splitScalar(u8, line, separator);
    while (parts.next()) |part| try fields.append(allocator, part);
    return fields.toOwnedSlice(allocator);
}

pub fn load(allocator: std.mem.Allocator, content: []const u8) !Table {
    return Table.load(allocator, content);
}

pub fn date(text: []const u8) !@import("nepdate").Date {
    const first = std.mem.indexOfScalar(u8, text, '-') orelse return error.BadDate;
    const last = std.mem.lastIndexOfScalar(u8, text, '-') orelse return error.BadDate;
    return @import("nepdate").Date.fromBs(
        try std.fmt.parseInt(i64, text[0..first], 10),
        try std.fmt.parseInt(i64, text[first + 1 .. last], 10),
        try std.fmt.parseInt(i64, text[last + 1 ..], 10),
    );
}

pub fn gregorian(text: []const u8) !@import("nepdate").Gregorian {
    const first = std.mem.indexOfScalar(u8, text, '-') orelse return error.BadDate;
    const last = std.mem.lastIndexOfScalar(u8, text, '-') orelse return error.BadDate;
    return .{
        .year = try std.fmt.parseInt(i32, text[0..first], 10),
        .month = try std.fmt.parseInt(u8, text[first + 1 .. last], 10),
        .day = try std.fmt.parseInt(u8, text[last + 1 ..], 10),
    };
}

pub fn expectDate(expected: []const u8, actual: @import("nepdate").Date) !void {
    var buffer: [24]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(actual.year())),
        @as(u32, @intCast(actual.monthNumber())),
        @as(u32, @intCast(actual.day())),
    });
    try std.testing.expectEqualStrings(expected, text);
}

pub fn expectGregorian(expected: []const u8, actual: @import("nepdate").Gregorian) !void {
    var buffer: [24]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(actual.year)),
        @as(u32, @intCast(actual.month)),
        @as(u32, @intCast(actual.day)),
    });
    try std.testing.expectEqualStrings(expected, text);
}
