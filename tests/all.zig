const std = @import("std");
const core = @import("nepdate");
const patro = @import("nepdate_patro");

comptime {
    _ = @import("vectors_core.zig");
    _ = @import("vectors_arith.zig");
    _ = @import("vectors_text.zig");
    _ = @import("vectors_range.zig");
    _ = @import("property_test.zig");
    _ = @import("patro_test.zig");
    _ = @import("fuzz_test.zig");
    _ = @import("catalog_test.zig");
    _ = @import("public_api_test.zig");
}

test "core and patro load" {
    const date = try core.Date.fromBs(2081, 4, 15);
    try std.testing.expectEqual(@as(i32, 2081), date.year());
    _ = patro;
}
