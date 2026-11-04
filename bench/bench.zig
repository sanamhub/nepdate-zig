//! B1 to B8 from spec/BENCHMARK.md, for the Zig wrapper and for the C
//! amalgamation underneath it. Run with `zig build bench`.

const std = @import("std");
const nepdate = @import("nepdate");
const patro = @import("nepdate_patro");

var bench_io: std.Io = undefined;

const passes = 5;

const RawDate = extern struct { value: i32 };
const RawYmd = extern struct { year: i32, month: i32, day: i32 };
const RawStatus = enum(c_int) { ok = 0 };
const RawRange = extern struct { start: RawDate, end: RawDate };
const RawIterator = extern struct { current: i32, last: i32 };
const RawLongOptions = extern struct { weekday: bool, year: bool, pad: bool };

extern fn nepdate_from_bs(year: i32, month: i32, day: i32, out: *RawDate) RawStatus;
extern fn nepdate_to_ad(value: RawDate, out: *RawYmd) RawStatus;
extern fn nepdate_to_bs(value: RawDate, out: *RawYmd) RawStatus;
extern fn nepdate_from_ad(year: i32, month: i32, day: i32, out: *RawDate) RawStatus;
extern fn nepdate_add_days(value: RawDate, days: i32, out: *RawDate) RawStatus;
extern fn nepdate_add_months(value: RawDate, months: i32, mode: c_int, out: *RawDate) RawStatus;
extern fn nepdate_format_long(
    value: RawDate,
    options: RawLongOptions,
    language: c_int,
    buffer: [*c]u8,
    size: usize,
) usize;
extern fn nepdate_parse(text: [*c]const u8, len: usize, out: *RawDate) RawStatus;
extern fn nepdate_patro_info(value: RawDate, out: *RawPatroInfo) RawStatus;
extern fn nepdate_patro_events(value: RawDate, events: [*c]RawPatroName, capacity: usize) usize;
extern fn nepdate_range_of_month(year: i32, month: i32, out: *RawRange) RawStatus;
extern fn nepdate_range_begin(value: RawRange, out: *RawIterator) RawStatus;
extern fn nepdate_range_next(iterator: *RawIterator, out: *RawDate) bool;

const RawPatroName = extern struct {
    np: [*c]const u8,
    np_length: usize,
    en: [*c]const u8,
    en_length: usize,
};

const RawPatroInfo = extern struct {
    has_tithi: bool,
    tithi: RawPatroName,
    is_public_holiday: bool,
    event_count: usize,
};

const Sample = struct {
    bs: nepdate.Date,
    ad: nepdate.Gregorian,
    patro_date: nepdate.Date,
};

pub fn main(init: std.process.Init) !void {
    bench_io = init.io;
    const allocator = init.gpa;
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    var iterations: u32 = 2000;
    if (args.next()) |arg| iterations = try std.fmt.parseInt(u32, arg, 10);

    var samples: [64]Sample = undefined;
    const first = try nepdate.Date.fromBs(2000, 1, 1);
    const last = try nepdate.Date.fromBs(2090, 12, 30);
    const span = first.daysUntil(last);
    const step = @divTrunc(span, 63);
    const patro_start = patro.coverage().start;
    const patro_end = patro.coverage().end;
    const patro_span = patro_start.daysUntil(patro_end);
    const patro_step = @divTrunc(patro_span, 63);

    for (&samples, 0..) |*sample, i| {
        const date = try first.addDays(@intCast(@as(i32, @intCast(i)) * step));
        sample.* = .{
            .bs = date,
            .ad = date.toGregorian(),
            .patro_date = try patro_start.addDays(@intCast(@as(i32, @intCast(i)) * patro_step)),
        };
    }

    std.debug.print("# B1 to B8, 64 inputs, {d} iterations\n\n", .{iterations});
    std.debug.print("| ID | Zig wrapper ns/op | C core ns/op |\n", .{});
    std.debug.print("|---|---:|---:|\n", .{});

    try row("B1", iterations, &samples, b1Zig, b1C);
    try row("B2", iterations, &samples, b2Zig, b2C);
    try row("B3", iterations, &samples, b3Zig, b3C);
    try row("B4", iterations, &samples, b4Zig, b4C);
    try row("B5", iterations, &samples, b5Zig, b5C);
    try row("B6", iterations, &samples, b6Zig, b6C);
    try row("B7", iterations, &samples, b7Zig, b7C);
    try row("B8", iterations, &samples, b8Zig, b8C);
}

fn row(
    id: []const u8,
    iterations: u32,
    samples: *const [64]Sample,
    zig_fn: *const fn (Sample) anyerror!void,
    c_fn: *const fn (Sample) anyerror!void,
) !void {
    const warm = @max(20, iterations / 20);
    _ = try measure(warm, samples, zig_fn);
    _ = try measure(warm, samples, c_fn);

    var zig: [passes]f64 = undefined;
    var c: [passes]f64 = undefined;
    for (0..passes) |pass| {
        // Alternate the order so a frequency change does not favour one side.
        if (pass % 2 == 0) {
            zig[pass] = try measure(iterations, samples, zig_fn);
            c[pass] = try measure(iterations, samples, c_fn);
        } else {
            c[pass] = try measure(iterations, samples, c_fn);
            zig[pass] = try measure(iterations, samples, zig_fn);
        }
    }
    std.debug.print("| {s} | {d:.1} | {d:.1} |\n", .{ id, trimmedMean(&zig), trimmedMean(&c) });
}

/// Drops the fastest and slowest pass so one scheduler hiccup cannot move the row.
fn trimmedMean(values: *const [passes]f64) f64 {
    var sum: f64 = 0;
    var slowest: f64 = values[0];
    var fastest: f64 = values[0];
    for (values) |value| {
        sum += value;
        slowest = @max(slowest, value);
        fastest = @min(fastest, value);
    }
    return (sum - slowest - fastest) / @as(f64, @floatFromInt(passes - 2));
}

fn measure(
    iterations: u32,
    samples: *const [64]Sample,
    function: *const fn (Sample) anyerror!void,
) !f64 {
    const start = std.Io.Clock.Timestamp.now(bench_io, .awake);
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        for (samples) |sample| try function(sample);
    }
    const elapsed = start.untilNow(bench_io).raw.nanoseconds;
    return @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations * 64));
}

fn b1Zig(sample: Sample) !void {
    const date = try nepdate.Date.fromBs(sample.bs.year(), sample.bs.monthNumber(), sample.bs.day());
    std.mem.doNotOptimizeAway(date.toGregorian());
}

fn b1C(sample: Sample) !void {
    var raw: RawDate = undefined;
    var ad: RawYmd = undefined;
    _ = nepdate_from_bs(sample.bs.year(), sample.bs.monthNumber(), sample.bs.day(), &raw);
    _ = nepdate_to_ad(raw, &ad);
    std.mem.doNotOptimizeAway(ad);
}

fn b2Zig(sample: Sample) !void {
    const date = try nepdate.Date.fromGregorian(sample.ad.year, sample.ad.month, sample.ad.day);
    std.mem.doNotOptimizeAway(date.ymd());
}

fn b2C(sample: Sample) !void {
    var raw: RawDate = undefined;
    _ = nepdate_from_ad(sample.ad.year, sample.ad.month, sample.ad.day, &raw);
    var bs: RawYmd = undefined;
    _ = nepdate_to_bs(raw, &bs);
    std.mem.doNotOptimizeAway(bs);
}

fn b3Zig(sample: Sample) !void {
    std.mem.doNotOptimizeAway(try sample.bs.addDays(1000));
}

fn b3C(sample: Sample) !void {
    const raw: RawDate = .{ .value = sample.bs.value.value };
    var out: RawDate = undefined;
    _ = nepdate_add_days(raw, 1000, &out);
    std.mem.doNotOptimizeAway(out);
}

fn b4Zig(sample: Sample) !void {
    std.mem.doNotOptimizeAway(try sample.bs.addMonths(13, .clamp));
}

fn b4C(sample: Sample) !void {
    const raw: RawDate = .{ .value = sample.bs.value.value };
    var out: RawDate = undefined;
    _ = nepdate_add_months(raw, 13, 0, &out);
    std.mem.doNotOptimizeAway(out);
}

fn b5Zig(sample: Sample) !void {
    var buffer: [128]u8 = undefined;
    const text = try sample.bs.longTo(&buffer, .{ .lang = .ne, .weekday = true });
    std.mem.doNotOptimizeAway(text.len);
}

fn b5C(sample: Sample) !void {
    var buffer: [128]u8 = undefined;
    const raw: RawDate = .{ .value = sample.bs.value.value };
    const n = nepdate_format_long(raw, .{ .weekday = true, .year = true, .pad = true }, 1, &buffer, buffer.len);
    std.mem.doNotOptimizeAway(n);
}

fn b6Zig(sample: Sample) !void {
    var buffer: [16]u8 = undefined;
    const text = try std.fmt.bufPrint(&buffer, "{d:0>4}/{d:0>2}/{d:0>2}", .{
        @as(u32, @intCast(sample.bs.year())),
        @as(u32, @intCast(sample.bs.monthNumber())),
        @as(u32, @intCast(sample.bs.day())),
    });
    std.mem.doNotOptimizeAway(try nepdate.Date.parse(text));
}

fn b6C(sample: Sample) !void {
    var text_buffer: [16]u8 = undefined;
    const text = try std.fmt.bufPrint(&text_buffer, "{d:0>4}/{d:0>2}/{d:0>2}", .{
        @as(u32, @intCast(sample.bs.year())),
        @as(u32, @intCast(sample.bs.monthNumber())),
        @as(u32, @intCast(sample.bs.day())),
    });
    var raw: RawDate = undefined;
    _ = nepdate_parse(text.ptr, text.len, &raw);
    std.mem.doNotOptimizeAway(raw);
}

const nepdate_patr_name = struct {
    nepali: []const u8,
    english: []const u8,
};

const nepdate_patr_info = struct {
    tithi: ?nepdate_patr_name = null,
    is_public_holiday: bool = false,
    events: []const nepdate_patr_name = &.{},
    owns_events: bool = false,
};

fn nameFromC(value: RawPatroName) nepdate_patr_name {
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

fn b7Zig(sample: Sample) !void {
    var buffer: [16]patro.Event = undefined;
    const info = try patro.infoInto(sample.patro_date, &buffer);
    std.mem.doNotOptimizeAway(info.events.len);
}

fn b7C(sample: Sample) !void {
    var raw: RawPatroInfo = undefined;
    const date: RawDate = .{ .value = sample.patro_date.value.value };
    _ = nepdate_patro_info(date, &raw);
    var events: [16]RawPatroName = undefined;
    _ = nepdate_patro_events(date, &events, events.len);
    std.mem.doNotOptimizeAway(raw);
    std.mem.doNotOptimizeAway(events[0]);
}

fn b8Zig(sample: Sample) !void {
    const range = try nepdate.Range.forMonth(sample.patro_date.year(), sample.patro_date.monthNumber());
    var iterator = range.iterator();
    var count: usize = 0;
    var buffer: [16]patro.Event = undefined;
    while (iterator.next()) |date| {
        const info = try patro.infoInto(date, &buffer);
        count += info.events.len;
    }
    std.mem.doNotOptimizeAway(count);
}

fn b8C(sample: Sample) !void {
    var total: usize = 0;
    var range: RawRange = undefined;
    if (nepdate_range_of_month(
        sample.patro_date.year(),
        sample.patro_date.monthNumber(),
        &range,
    ) == .ok) {
        var iterator: RawIterator = undefined;
        if (nepdate_range_begin(range, &iterator) == .ok) {
            var raw: RawDate = undefined;
            while (nepdate_range_next(&iterator, &raw)) {
                var info: RawPatroInfo = undefined;
                _ = nepdate_patro_info(raw, &info);
                var events: [16]RawPatroName = undefined;
                _ = nepdate_patro_events(raw, &events, events.len);
                total += info.event_count;
            }
        }
    }
    std.mem.doNotOptimizeAway(total);
}
