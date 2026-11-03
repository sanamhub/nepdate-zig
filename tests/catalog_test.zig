const std = @import("std");
const common = @import("common.zig");
const testing = std.testing;

test "the C# test catalog is present and every row is accounted for" {
    var t = try common.load(
        testing.allocator,
        @embedFile("../shared/spec/vectors/csharp-tests/catalog.tsv"),
    );
    defer t.deinit();
    var phases = [_]usize{ 0, 0, 0, 0, 0 };
    var not_portable: usize = 0;
    var not_applicable: usize = 0;
    var row_count: usize = 0;
    for (t.rows) |row| {
        try testing.expect(row.get("id").len > 0);
        try testing.expect(row.get("file").len > 0);
        const phase = row.get("phase");
        if (std.mem.eql(u8, phase, "n/a")) {
            not_applicable += 1;
        } else if (std.mem.eql(u8, phase, "D-14")) {
            not_portable += 1;
        } else {
            const number = try std.fmt.parseInt(u8, phase, 10);
            try testing.expect(number >= 1 and number <= 4);
            phases[number] += 1;
        }
        row_count += 1;
    }
    try testing.expectEqual(@as(usize, 542), row_count);
    try testing.expectEqual(@as(usize, 542), phases[1] + phases[2] + phases[3] + phases[4] + not_portable + not_applicable);
    try testing.expectEqual(@as(usize, 17), not_portable);
    try testing.expectEqual(@as(usize, 44), not_applicable);
}
