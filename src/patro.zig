//! The Nepali patro: tithi, public holidays and events for BS 2077-01-01 to
//! 2084-08-20. The data lives in the vendored C amalgamation; this module
//! never reads JSON at runtime.

const std = @import("std");
const core = @import("nepdate");
const c = @import("patro_c.zig");

/// A bilingual name. `nepali` is UTF-8 Devanagari and `english` is UTF-8.
pub const Name = struct {
    nepali: []const u8,
    english: []const u8,

    pub fn name(self: Name, lang: core.Lang) []const u8 {
        return switch (lang) {
            .ne => self.nepali,
            .en => self.english,
        };
    }
};

pub const Tithi = Name;
pub const Event = Name;

/// Everything the patro says about one day.
pub const CalendarInfo = struct {
    tithi: ?Tithi = null,
    is_public_holiday: bool = false,
    events: []const Event = &.{},
    owns_events: bool = false,

    pub fn tithiNp(self: CalendarInfo) []const u8 {
        return if (self.tithi) |value| value.nepali else "";
    }

    pub fn tithiEn(self: CalendarInfo) []const u8 {
        return if (self.tithi) |value| value.english else "";
    }

    pub fn eventsNp(self: CalendarInfo, out: [][]const u8) core.Error![][]const u8 {
        if (out.len < self.events.len) return error.NoSpace;
        for (self.events, 0..) |event, i| out[i] = event.nepali;
        return out[0..self.events.len];
    }

    pub fn eventsEn(self: CalendarInfo, out: [][]const u8) core.Error![][]const u8 {
        if (out.len < self.events.len) return error.NoSpace;
        for (self.events, 0..) |event, i| out[i] = event.english;
        return out[0..self.events.len];
    }

    /// Frees the event array only when this value came from `info`.
    pub fn deinit(self: CalendarInfo, allocator: std.mem.Allocator) void {
        if (self.owns_events) allocator.free(self.events);
    }
};

fn nameFromC(value: c.patro_name) Name {
    const np = if (value.np_length == 0)
        ""
    else
        @as([*]const u8, @ptrCast(value.np))[0..value.np_length];
    const en = if (value.en_length == 0)
        ""
    else
        @as([*]const u8, @ptrCast(value.en))[0..value.en_length];
    return .{ .nepali = np, .english = en };
}

fn dateToC(value: core.Date) c.date {
    return .{ .value = value.value.value };
}

fn dateFromC(value: c.date) core.Date {
    return .{ .value = .{ .value = value.value } };
}

/// Looks up a day and returns its event array in the caller's buffer.
pub inline fn infoInto(date: core.Date, event_buffer: []Event) core.Error!CalendarInfo {
    var raw: c.patro_day_info = undefined;
    try core.checkStatusRaw(@backingInt(c.nepdate_patro_info(dateToC(date), &raw)));
    if (raw.event_count > event_buffer.len) return error.NoSpace;
    var written: usize = 0;
    if (raw.event_count > 0) {
        const raw_events: [*]c.patro_name = @ptrCast(event_buffer.ptr);
        written = c.nepdate_patro_events(dateToC(date), @ptrCast(raw_events), event_buffer.len);
        for (raw_events[0..written], 0..) |event, i| {
            event_buffer[i] = nameFromC(event);
        }
    }
    return .{
        .tithi = if (raw.has_tithi) nameFromC(raw.tithi) else null,
        .is_public_holiday = raw.is_public_holiday,
        .events = event_buffer[0..written],
    };
}

/// Looks up a day and allocates its event array. Free it with `deinit`.
pub fn info(allocator: std.mem.Allocator, date: core.Date) core.Error!CalendarInfo {
    var raw: c.patro_day_info = undefined;
    try core.checkStatusRaw(@backingInt(c.nepdate_patro_info(dateToC(date), &raw)));
    if (raw.event_count == 0) {
        return .{
            .tithi = if (raw.has_tithi) nameFromC(raw.tithi) else null,
            .is_public_holiday = raw.is_public_holiday,
            .events = &.{},
        };
    }
    var allocated_events = try allocator.alloc(Event, raw.event_count);
    errdefer allocator.free(allocated_events);
    const raw_events: [*]c.patro_name = @ptrCast(allocated_events.ptr);
    const written = c.nepdate_patro_events(dateToC(date), @ptrCast(raw_events), allocated_events.len);
    for (raw_events[0..written], 0..) |event, i| {
        allocated_events[i] = nameFromC(event);
    }
    return .{
        .tithi = if (raw.has_tithi) nameFromC(raw.tithi) else null,
        .is_public_holiday = raw.is_public_holiday,
        .events = allocated_events[0..written],
        .owns_events = true,
    };
}

/// The smallest range containing every day with metadata.
pub fn coverage() core.Range {
    const value = c.nepdate_patro_coverage();
    return .{ .start = dateFromC(value.start), .end = dateFromC(value.end) };
}

/// Writes the holiday dates into `buffer`, in ascending order.
pub fn publicHolidaysInto(buffer: []core.Date) core.Error![]core.Date {
    const count = c.nepdate_patro_public_holidays(null, 0);
    if (count > buffer.len) return error.NoSpace;
    const raw_dates: [*]c.date = @ptrCast(buffer.ptr);
    const written = c.nepdate_patro_public_holidays(@ptrCast(raw_dates), buffer.len);
    for (raw_dates[0..written], 0..) |date, i| {
        buffer[i] = dateFromC(date);
    }
    return buffer[0..written];
}

/// All holiday dates, allocated by the caller's allocator.
pub fn publicHolidays(allocator: std.mem.Allocator) core.Error![]core.Date {
    const count = c.nepdate_patro_public_holidays(null, 0);
    const dates = try allocator.alloc(core.Date, count);
    errdefer allocator.free(dates);
    const raw_dates: [*]c.date = @ptrCast(dates.ptr);
    const written = c.nepdate_patro_public_holidays(@ptrCast(raw_dates), dates.len);
    for (raw_dates[0..written], 0..) |date, i| {
        dates[i] = dateFromC(date);
    }
    return dates[0..written];
}

/// The events of a day into a caller buffer.
pub fn events(date: core.Date, buffer: []Event) core.Error![]Event {
    const count = c.nepdate_patro_events(dateToC(date), null, 0);
    if (count > buffer.len) return error.NoSpace;
    const raw_events: [*]c.patro_name = @ptrCast(buffer.ptr);
    const written = c.nepdate_patro_events(dateToC(date), @ptrCast(raw_events), buffer.len);
    for (raw_events[0..written], 0..) |event, i| {
        buffer[i] = nameFromC(event);
    }
    return buffer[0..written];
}

test "patro anchors" {
    var buffer: [8]Event = undefined;
    const new_year = try infoInto(try core.Date.fromBs(2081, 1, 1), &buffer);
    try std.testing.expectEqualStrings("Panchami", new_year.tithiEn());
    try std.testing.expect(new_year.is_public_holiday);
    try std.testing.expectEqual(@as(usize, 3), new_year.events.len);
    try std.testing.expectEqualStrings("New Year", new_year.events[0].english);
}
