//! Hand-written declarations for the patro half of the vendored C amalgamation.
//! The core module owns the other half; this file keeps the two modules disjoint.

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

pub const range = extern struct {
    start: date,
    end: date,
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

pub extern fn nepdate_patro_info(value: date, out: *patro_day_info) status;
pub extern fn nepdate_patro_coverage() range;
pub extern fn nepdate_patro_public_holidays(dates: [*c]date, capacity: usize) usize;
pub extern fn nepdate_patro_events(
    value: date,
    events: [*c]patro_name,
    capacity: usize,
) usize;
