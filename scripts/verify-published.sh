#!/usr/bin/env bash
# Fetch one released tag the way a user does and run a small program with both modules.
set -euo pipefail

version="${1:?usage: verify-published.sh VERSION}"
tag="v${version}"
url="https://github.com/sanamhub/nepdate-zig/archive/refs/tags/${tag}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

cat > build.zig <<'EOF'
const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep = b.dependency("nepdate", .{ .target = target, .optimize = optimize });
    const exe = b.addExecutable(.{
        .name = "check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nepdate", .module = dep.module("nepdate") },
                .{ .name = "nepdate_patro", .module = dep.module("nepdate_patro") },
            },
        }),
    });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run the sample").dependOn(&run.step);
}
EOF

cat > build.zig.zon <<'EOF'
.{
    .name = .nepdate_verify,
    .version = "0.0.0",
    .fingerprint = 0x8f7def9b5f87632d,
    .minimum_zig_version = "0.17.0",
    .dependencies = .{},
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
EOF

mkdir -p src
cat > src/main.zig <<'EOF'
const std = @import("std");
const nepdate = @import("nepdate");
const patro = @import("nepdate_patro");

pub fn main() !void {
    const date = try nepdate.Date.fromBs(2081, 4, 15);
    var buffer: [16]u8 = undefined;
    const iso = try date.toJsonAlloc(std.heap.smp_allocator);
    defer std.heap.smp_allocator.free(iso);
    if (!std.mem.eql(u8, iso, "2081-04-15")) return error.BadDate;
    if (!std.mem.eql(u8, try date.write(&buffer), "2081/04/15")) return error.BadDisplay;
    var events: [8]patro.Event = undefined;
    const info = try patro.infoInto(try nepdate.Date.fromBs(2081, 1, 1), &events);
    if (info.events.len != 3) return error.BadPatro;
    std.debug.print("{s} {s}\n", .{ iso, info.tithiEn() });
}
EOF

zig fetch --save "$url"
zig build run
