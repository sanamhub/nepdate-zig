//! Calls the public surface that the vector suites do not touch directly, so
//! `tools/check_public_api.py` can prove every public function has a test.

const std = @import("std");
const core = @import("nepdate");
const patro = @import("nepdate_patro");

const allocator = std.testing.allocator;

test "date members beyond the vectors" {
    const date = try core.Date.fromBs(2081, 4, 15);
    const later = try core.Date.fromBs(2081, 4, 20);

    try std.testing.expect(date.isValid());
    const empty = core.Date{ .value = .{ .value = 0 } };
    try std.testing.expect(empty.isDefault());
    try std.testing.expect(!empty.isValid());
    try std.testing.expectEqual(core.Weekday.tuesday, date.weekday());
    try std.testing.expectEqual(date.monthLength(), date.lastDayOfMonth().day());
    try std.testing.expectEqual(date.lastDayOfMonth(), date.monthEndDate());
    try std.testing.expectEqual(@as(u8, 1), date.firstDayOfMonth().day());

    try std.testing.expect(date.eql(date));
    try std.testing.expectEqual(std.math.Order.lt, date.compare(later));
    try std.testing.expect(date.lessThan(later));
    try std.testing.expect(date.lessThanOrEqual(date));
    try std.testing.expect(later.greaterThan(date));
    try std.testing.expect(later.greaterThanOrEqual(later));

    const difference = date.diff(later);
    try std.testing.expectEqual(@as(i32, 5), difference.total_days);
    try std.testing.expect(!difference.negative());
    try std.testing.expect(later.diff(try core.Date.fromBs(2081, 4, 10)).negative());

    try std.testing.expectEqual(@as(i32, 2081), date.fiscalYear().year);
    try std.testing.expectEqual(date, try core.Date.fromEnglish(
        date.toGregorian().year,
        date.toGregorian().month,
        date.toGregorian().day,
    ));
    const record = date.toRecord();
    try std.testing.expectEqual(@as(i32, 2081), record.year);
    try std.testing.expectEqual(@as(u8, 4), record.month);
    try std.testing.expectEqual(@as(u8, 15), record.day);

    const iso = try date.toStringAlloc(allocator);
    defer allocator.free(iso);
    var buffer: [16]u8 = undefined;
    try std.testing.expectEqualStrings(try date.write(&buffer), iso);

    var short_buffer: [32]u8 = undefined;
    const short_alloc = try date.shortAlloc(allocator, .{ .order = .dmy, .separator = .dash });
    defer allocator.free(short_alloc);
    try std.testing.expectEqualStrings(
        short_alloc,
        try date.shortTo(&short_buffer, .{ .order = .dmy, .separator = .dash }),
    );
    var long_buffer: [128]u8 = undefined;
    const long_alloc = try date.longAlloc(allocator, .{ .weekday = true });
    defer allocator.free(long_alloc);
    try std.testing.expectEqualStrings(
        long_alloc,
        try date.longTo(&long_buffer, .{ .weekday = true }),
    );

    const formatted = try std.fmt.allocPrint(allocator, "{f}", .{date});
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings(iso, formatted);
    try std.testing.expectEqual(@as(u32, @bitCast(date.value.value)), date.hash());
    try std.testing.expect((try core.Date.now(core.nepal_offset_minutes, 1_700_000_000)).isValid());
}

test "months, weekdays, quarters and zones" {
    try std.testing.expectEqual(@as(u8, 1), core.Month.baishakh.number());
    try std.testing.expectEqualStrings("Baishakh", core.Month.baishakh.englishName());
    try std.testing.expectEqualStrings("बैशाख", core.Month.baishakh.nepaliName());
    try std.testing.expectEqualStrings("Sunday", core.Weekday.sunday.englishName());
    try std.testing.expectEqualStrings("आइतवार", core.Weekday.sunday.nepaliName());
    try std.testing.expectEqual(@as(u8, 1), core.Quarter.q1.number());
    try std.testing.expectEqual(@as(i32, 345), core.Zone.nepal.offsetMinutes());
    try std.testing.expectEqual(@as(i32, 0), core.Zone.utc.offsetMinutes());
}

test "bulk conversion aliases" {
    const ad = [_]core.Gregorian{
        .{ .year = 2024, .month = 7, .day = 30 },
        .{ .year = 2024, .month = 8, .day = 1 },
    };
    var bs: [2]core.Date = undefined;
    const converted = try core.batchToNepaliDates(&ad, &bs);
    try std.testing.expectEqual(@as(usize, 2), converted.len);
    var back: [2]core.Gregorian = undefined;
    const round_trip = try core.batchToEnglishDates(converted, &back);
    try std.testing.expectEqual(ad[0].year, round_trip[0].year);
    try std.testing.expectEqual(ad[1].month, round_trip[1].month);
    try std.testing.expectEqualStrings("1.0.0-rc.1", core.version);
    try std.testing.expect(core.vendorVersion().len > 0);
}

test "fiscal year members beyond the vectors" {
    const fiscal = try core.FiscalYear.init(2081);
    const span = try fiscal.range();
    try std.testing.expectEqual(try fiscal.start(), span.start);
    try std.testing.expectEqual(try fiscal.end(), span.end);
    try std.testing.expectEqual(std.math.Order.lt, fiscal.compare(try core.FiscalYear.init(2082)));

    const label = try fiscal.labelAlloc(allocator, .ne);
    defer allocator.free(label);
    try std.testing.expect(label.len > 0);
}

test "range members beyond the vectors" {
    const start = try core.Date.fromBs(2081, 4, 10);
    const end = try core.Date.fromBs(2081, 4, 20);
    const span = try core.Range.of(start, end);

    try std.testing.expectEqual(@as(i32, 11), span.length());
    var days = span.days();
    var day_count: usize = 0;
    while (days.next()) |_| day_count += 1;
    try std.testing.expectEqual(@as(usize, 11), day_count);
    try std.testing.expectEqual(span.hash(), span.hash());
    var buffer: [64]u8 = undefined;
    const formatted = try std.fmt.allocPrint(allocator, "{f}", .{span});
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings(try span.write(&buffer), formatted);
}

test "current ranges and exceptAlloc" {
    const unix = 1_700_000_000;
    try std.testing.expect((try core.Range.currentMonth(core.nepal_offset_minutes, unix)).length() > 0);
    try std.testing.expect((try core.Range.currentFiscalYear(
        core.nepal_offset_minutes,
        unix,
    )).length() > 0);
    try std.testing.expect((try core.Range.currentCalendarYear(
        core.nepal_offset_minutes,
        unix,
    )).length() > 0);

    const whole = try core.Range.of(
        try core.Date.fromBs(2081, 4, 1),
        try core.Date.fromBs(2081, 4, 30),
    );
    const middle = try core.Range.of(
        try core.Date.fromBs(2081, 4, 10),
        try core.Date.fromBs(2081, 4, 20),
    );
    const pieces = try whole.exceptAlloc(allocator, middle);
    defer allocator.free(pieces);
    try std.testing.expectEqual(@as(usize, 2), pieces.len);
}

test "patro names and buffers" {
    const date = try core.Date.fromBs(2081, 1, 1);
    var events: [8]patro.Event = undefined;
    const info = try patro.infoInto(date, &events);
    try std.testing.expect(info.tithi != null);
    try std.testing.expectEqualStrings("Panchami", info.tithi.?.name(.en));
    try std.testing.expectEqualStrings(info.tithi.?.nepali, info.tithiNp());
    try std.testing.expect(info.events.len > 0);

    var nepali: [8][]const u8 = undefined;
    var english: [8][]const u8 = undefined;
    try std.testing.expectEqual(info.events.len, (try info.eventsNp(&nepali)).len);
    try std.testing.expectEqual(info.events.len, (try info.eventsEn(&english)).len);
    try std.testing.expectEqualStrings("New Year", english[0]);

    try std.testing.expectEqual(info.events.len, (try patro.events(date, &events)).len);
    var holidays: [800]core.Date = undefined;
    const written = try patro.publicHolidaysInto(&holidays);
    try std.testing.expect(written.len > 0);
}
