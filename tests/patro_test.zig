const std = @import("std");
const core = @import("nepdate");
const patro = @import("nepdate_patro");
const common = @import("common.zig");
const testing = std.testing;

test "patro anchors" {
    const cases = [_]struct {
        date: []const u8,
        tithi: []const u8,
        holiday: bool,
        events: []const []const u8,
    }{
        .{ .date = "2081-01-01", .tithi = "Panchami", .holiday = true, .events = &.{ "New Year", "Mesh Sankranti", "Bisket Jatra" } },
        .{ .date = "2081-01-02", .tithi = "Shashthi", .holiday = false, .events = &.{} },
        .{ .date = "2081-02-15", .tithi = "Panchami", .holiday = true, .events = &.{"Republic Day"} },
        .{ .date = "2080-11-01", .tithi = "Chaturthi", .holiday = false, .events = &.{ "Mangala Chauthi Brata", "People's War Day", "Tilakund Chauthi", "Kumbha Sankranti", "World Radio Day" } },
        .{ .date = "2081-04-15", .tithi = "Dashami", .holiday = false, .events = &.{ "Kheer Khane Din", "World Day Against Human Trafficking", "International Friendship Day" } },
    };
    var buffer: [16]patro.Event = undefined;
    for (cases) |case| {
        const date = try common.date(case.date);
        const info = try patro.infoInto(date, &buffer);
        try testing.expectEqualStrings(case.tithi, info.tithiEn());
        try testing.expectEqual(case.holiday, info.is_public_holiday);
        try testing.expectEqual(case.events.len, info.events.len);
        for (case.events, 0..) |expected, i| {
            try testing.expectEqualStrings(expected, info.events[i].english);
        }
    }
}

test "patro coverage and empty days" {
    const coverage = patro.coverage();
    try common.expectDate("2077-01-01", coverage.start);
    try common.expectDate("2084-08-20", coverage.end);
    try testing.expectEqual(@as(i32, 2793), coverage.length());

    var buffer: [16]patro.Event = undefined;
    for ([_][]const u8{ "2070-06-15", "2090-01-01" }) |text| {
        const info = try patro.infoInto(try common.date(text), &buffer);
        try testing.expectEqual(@as(?patro.Tithi, null), info.tithi);
        try testing.expect(!info.is_public_holiday);
        try testing.expectEqual(@as(usize, 0), info.events.len);
    }
}

test "patro summary counts" {
    var buf: [16]patro.Event = undefined;
    var tithi_days: usize = 0;
    var holidays: usize = 0;
    var event_days: usize = 0;
    var events: usize = 0;
    var date = patro.coverage().start;
    while (true) {
        const info = try patro.infoInto(date, &buf);
        if (info.tithi != null) tithi_days += 1;
        if (info.is_public_holiday) holidays += 1;
        if (info.events.len > 0) event_days += 1;
        events += info.events.len;
        if (date.eql(patro.coverage().end)) break;
        date = try date.addDays(1);
    }
    try testing.expectEqual(@as(usize, 2190), tithi_days);
    try testing.expectEqual(@as(usize, 294), holidays);
    try testing.expectEqual(@as(usize, 1671), event_days);
    try testing.expectEqual(@as(usize, 3032), events);
}

test "public holidays are ascending and complete" {
    const dates = try patro.publicHolidays(testing.allocator);
    defer testing.allocator.free(dates);
    try testing.expectEqual(@as(usize, 294), dates.len);
    var previous = dates[0];
    for (dates[1..]) |date| {
        try testing.expect(previous.lessThan(date));
        previous = date;
    }
    for (dates) |date| {
        var buffer: [16]patro.Event = undefined;
        try testing.expect((try patro.infoInto(date, &buffer)).is_public_holiday);
    }
}

test "allocated patro info owns only the event list" {
    const info = try patro.info(testing.allocator, try common.date("2080-11-01"));
    defer info.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 5), info.events.len);
    try testing.expectEqualStrings("Chaturthi", info.tithiEn());
    try testing.expect(!info.is_public_holiday);
}
