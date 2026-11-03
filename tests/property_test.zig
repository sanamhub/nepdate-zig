const std = @import("std");
const core = @import("nepdate");
const testing = std.testing;

test "serial round trip over every supported day" {
    var date = core.Date.min;
    var count: usize = 0;
    while (true) : (count += 1) {
        const ad = date.toGregorian();
        const back = try core.Date.fromGregorian(ad.year, ad.month, ad.day);
        try testing.expect(date.eql(back));
        const ymd = date.ymd();
        try testing.expect(date.eql(try core.Date.fromYmd(ymd)));
        if (date.eql(core.Date.max)) break;
        date = try date.addDays(1);
    }
    try testing.expectEqual(@as(usize, 109211), count);
}

test "seeded round trips for arithmetic and text" {
    var prng = std.Random.DefaultPrng.init(0x5eed_2081);
    const random = prng.random();
    var count: usize = 0;
    while (count < 5000) : (count += 1) {
        const year = random.intRangeAtMost(i64, 1901, 2199);
        const month = random.intRangeAtMost(i64, 1, 12);
        const first = try core.Date.fromBs(year, month, 1);
        const day = random.intRangeAtMost(i64, 1, first.monthLength());
        const date = try core.Date.fromBs(year, month, day);

        try testing.expect(date.eql(try core.Date.fromYmd(date.ymd())));
        const iso = try date.toJsonAlloc(testing.allocator);
        defer testing.allocator.free(iso);
        try testing.expect(date.eql(try core.Date.parse(iso)));

        const delta = random.intRangeAtMost(i32, -10000, 10000);
        const shifted = date.addDays(delta) catch continue;
        try testing.expect(date.eql(try shifted.addDays(-delta)));

        const range = core.Range.single(date);
        var iterator = range.iterator();
        try testing.expect(iterator.next().?.eql(date));
        try testing.expectEqual(@as(?core.Date, null), iterator.next());
    }
}
