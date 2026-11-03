//! Hand-written declarations for the public C API of the vendored amalgamation.
//!
//! Zig 0.17 removed `@cImport`, so this file is the only bridge to
//! `vendor/nepdate-c/nepdate.h` and `vendor/nepdate-c/nepdate_patro.h`.
//! The C symbols are private to the package; `nepdate` and `nepdate_patro`
//! expose the idiomatic surface.

pub const status = enum(c_int) {
    ok = 0,
    out_of_range = 1,
    invalid_month = 2,
    invalid_day = 3,
    invalid_gregorian = 4,
    invalid_character = 5,
    wrong_group_count = 6,
    number_too_long = 7,
    ambiguous = 8,
    unrecognized = 9,
    invalid_date = 10,
    null_argument = 11,
    no_overlap = 12,
};

pub const date = extern struct {
    value: i32,
};

pub const ymd = extern struct {
    year: c_int,
    month: c_int,
    day: c_int,
};

pub const text = extern struct {
    text: [*c]const u8,
    length: usize,
};

pub const month = enum(c_int) {
    baishakh = 1,
    jestha = 2,
    ashad = 3,
    shrawan = 4,
    bhadra = 5,
    ashoj = 6,
    kartik = 7,
    mangsir = 8,
    poush = 9,
    magh = 10,
    falgun = 11,
    chaitra = 12,
};

pub const weekday = enum(c_int) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,
};

pub const quarter = enum(c_int) {
    q1 = 1,
    q2 = 2,
    q3 = 3,
    q4 = 4,
};

pub const overflow = enum(c_int) {
    clamp = 0,
    spill = 1,
};

pub const lang = enum(c_int) {
    english = 0,
    nepali = 1,
};

pub const order = enum(c_int) {
    ymd = 0,
    ydm = 1,
    myd = 2,
    mdy = 3,
    dym = 4,
    dmy = 5,
};

pub const separator = enum(c_int) {
    slash = '/',
    backslash = '\\',
    dot = '.',
    underscore = '_',
    dash = '-',
    space = ' ',
};

pub const long_options = extern struct {
    weekday: bool,
    year: bool,
    pad: bool,
};

pub const date_diff = extern struct {
    sign: c_int,
    years: c_int,
    months: c_int,
    days: c_int,
};

pub const range = extern struct {
    start: date,
    end: date,
};

pub const range_iterator = extern struct {
    current: i32,
    last: i32,
};

pub const range_day_cursor = extern struct {
    current: i32,
    last: i32,
    step: i32,
    skip: u32,
};

pub const patro_name = extern struct {
    np: [*c]const u8,
    np_length: usize,
    en: [*c]const u8,
    en_length: usize,
};

pub const patro_day_info = extern struct {
    has_tithi: bool,
    tithi: patro_name,
    is_public_holiday: bool,
    event_count: usize,
};

pub const MIN_YEAR: c_int = 1901;
pub const MAX_YEAR: c_int = 2199;

pub extern fn nepdate_version() [*:0]const u8;
pub extern fn nepdate_min() date;
pub extern fn nepdate_max() date;
pub extern fn nepdate_status_name(value: status) [*:0]const u8;

pub extern fn nepdate_from_bs(year: c_int, month: c_int, day: c_int, out: *date) status;
pub extern fn nepdate_to_bs(value: date, out: *ymd) status;
pub extern fn nepdate_from_ad(year: c_int, month: c_int, day: c_int, out: *date) status;
pub extern fn nepdate_to_ad(value: date, out: *ymd) status;
pub extern fn nepdate_weekday_of(value: date, out: *weekday) status;
pub extern fn nepdate_month_of(value: date, out: *month) status;
pub extern fn nepdate_day_of_year(value: date, out: *c_int) status;
pub extern fn nepdate_month_length(value: date, out: *c_int) status;
pub extern fn nepdate_year_length(value: date, out: *c_int) status;
pub extern fn nepdate_first_day_of_month(value: date, out: *date) status;
pub extern fn nepdate_last_day_of_month(value: date, out: *date) status;
pub extern fn nepdate_compare(a: date, b: date, out: *c_int) status;

pub extern fn nepdate_add_days(value: date, days: i32, out: *date) status;
pub extern fn nepdate_add_months(value: date, months: i32, mode: overflow, out: *date) status;
pub extern fn nepdate_add_years(value: date, years: i32, mode: overflow, out: *date) status;
pub extern fn nepdate_diff_days(a: date, b: date, out: *i32) status;
pub extern fn nepdate_diff(a: date, b: date, out: *date_diff) status;

pub extern fn nepdate_fiscal_year_of(value: date, out: *c_int) status;
pub extern fn nepdate_fiscal_year_start(fiscal_year: c_int, out: *date) status;
pub extern fn nepdate_fiscal_year_end(fiscal_year: c_int, out: *date) status;
pub extern fn nepdate_quarter_of(value: date, out: *quarter) status;
pub extern fn nepdate_quarter_start(fiscal_year: c_int, value: quarter, out: *date) status;
pub extern fn nepdate_quarter_end(fiscal_year: c_int, value: quarter, out: *date) status;
pub extern fn nepdate_fiscal_year_label(
    fiscal_year: c_int,
    language: lang,
    buffer: [*c]u8,
    size: usize,
) usize;

pub extern fn nepdate_format(
    value: date,
    pattern: [*c]const u8,
    language: lang,
    buffer: [*c]u8,
    size: usize,
) usize;
pub extern fn nepdate_format_iso(value: date, buffer: [*c]u8, size: usize) usize;
pub extern fn nepdate_format_short(
    value: date,
    field_order: order,
    field_separator: separator,
    pad: bool,
    language: lang,
    buffer: [*c]u8,
    size: usize,
) usize;
pub extern fn nepdate_format_long(
    value: date,
    options: long_options,
    language: lang,
    buffer: [*c]u8,
    size: usize,
) usize;

pub extern fn nepdate_from_unix(unix_seconds: i64, offset_minutes: i32, out: *date) status;
pub extern fn nepdate_today_nepal(unix_seconds: i64, out: *date) status;
pub extern fn nepdate_today(offset_minutes: i32, unix_seconds: i64, out: *date) status;
pub extern fn nepdate_is_today(value: date, offset_minutes: i32, unix_seconds: i64, out: *bool) status;
pub extern fn nepdate_is_yesterday(value: date, offset_minutes: i32, unix_seconds: i64, out: *bool) status;
pub extern fn nepdate_is_tomorrow(value: date, offset_minutes: i32, unix_seconds: i64, out: *bool) status;

pub extern fn nepdate_parse(bytes: [*c]const u8, length: usize, out: *date) status;
pub extern fn nepdate_parse_lenient(bytes: [*c]const u8, length: usize, out: *date) status;
pub extern fn nepdate_from_ymd_int(value: i64, out: *date) status;
pub extern fn nepdate_to_ymd_int(value: date, out: *i64) status;

pub extern fn nepdate_bulk_to_bs(
    ad: [*c]const ymd,
    count: usize,
    out: [*c]date,
    capacity: usize,
    written: *usize,
) status;
pub extern fn nepdate_bulk_parse_to_ad(
    texts: [*c]const text,
    count: usize,
    out: [*c]ymd,
    capacity: usize,
    written: *usize,
) status;
pub extern fn nepdate_bulk_to_ad(
    dates: [*c]const date,
    count: usize,
    out: [*c]ymd,
    capacity: usize,
    written: *usize,
) status;

pub extern fn nepdate_range_make(start: date, end: date, out: *range) status;
pub extern fn nepdate_range_of_month(year: c_int, month: c_int, out: *range) status;
pub extern fn nepdate_range_of_year(year: c_int, out: *range) status;
pub extern fn nepdate_range_of_fiscal_year(fiscal_year: c_int, out: *range) status;
pub extern fn nepdate_range_length(value: range, out: *c_int) status;
pub extern fn nepdate_range_contains(value: range, day: date, out: *bool) status;
pub extern fn nepdate_range_begin(value: range, out: *range_iterator) status;
pub extern fn nepdate_range_next(iterator: *range_iterator, out: *date) bool;
pub extern fn nepdate_range_from_day_count(start: date, days: i32, out: *range) status;
pub extern fn nepdate_range_current_month(offset_minutes: i32, unix_seconds: i64, out: *range) status;
pub extern fn nepdate_range_current_fiscal_year(offset_minutes: i32, unix_seconds: i64, out: *range) status;
pub extern fn nepdate_range_current_calendar_year(offset_minutes: i32, unix_seconds: i64, out: *range) status;
pub extern fn nepdate_range_contains_range(value: range, other: range, out: *bool) status;
pub extern fn nepdate_range_overlaps(value: range, other: range, out: *bool) status;
pub extern fn nepdate_range_is_adjacent_to(value: range, other: range, out: *bool) status;
pub extern fn nepdate_range_intersect(value: range, other: range, out: *range) status;
pub extern fn nepdate_range_union(value: range, other: range, out: *range) status;
pub extern fn nepdate_range_except(value: range, other: range, out: [*c]range, written: *usize) status;
pub extern fn nepdate_range_split_by_month(
    value: range,
    out: [*c]range,
    capacity: usize,
    written: *usize,
) status;
pub extern fn nepdate_range_split_by_fiscal_quarter(
    value: range,
    out: [*c]range,
    capacity: usize,
    written: *usize,
) status;
pub extern fn nepdate_range_dates_with_interval(
    value: range,
    interval: i32,
    out: *range_day_cursor,
) status;
pub extern fn nepdate_range_working_days(
    value: range,
    exclude_sunday: bool,
    out: *range_day_cursor,
) status;
pub extern fn nepdate_range_weekend_days(
    value: range,
    include_sunday: bool,
    out: *range_day_cursor,
) status;
pub extern fn nepdate_range_day_next(cursor: *range_day_cursor, out: *date) bool;
pub extern fn nepdate_range_format(value: range, buffer: [*c]u8, size: usize) usize;
pub extern fn nepdate_range_format_short(
    value: range,
    field_order: order,
    field_separator: separator,
    language: lang,
    buffer: [*c]u8,
    size: usize,
) usize;
pub extern fn nepdate_range_equal(a: range, b: range, out: *bool) status;

pub extern fn nepdate_patro_info(value: date, out: *patro_day_info) status;
pub extern fn nepdate_patro_coverage() range;
pub extern fn nepdate_patro_public_holidays(dates: [*c]date, capacity: usize) usize;
pub extern fn nepdate_patro_events(
    value: date,
    events: [*c]patro_name,
    capacity: usize,
) usize;
