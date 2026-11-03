const std = @import("std");

const c_flags = &.{
    "-std=c11",
    "-DNEPDATE_STATIC",
    "-DNEPDATE_PATRO_STATIC",
    "-DNEPDATE_C_WITH_TM=0",
    "-fno-sanitize-coverage=trace-cmp",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core = b.addModule("nepdate", .{
        .root_source_file = b.path("src/nepdate.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    addC(core, b);

    const patro = b.addModule("nepdate_patro", .{
        .root_source_file = b.path("src/patro.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "nepdate", .module = core }},
    });

    const test_module = b.createModule(.{
        .root_source_file = b.path("test_root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "nepdate", .module = core },
            .{ .name = "nepdate_patro", .module = patro },
        },
    });
    const tests = b.addTest(.{ .root_module = test_module });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run the core, patro and shared-vector tests");
    test_step.dependOn(&run_tests.step);

    const core_tests = b.addTest(.{ .root_module = core });
    const run_core_tests = b.addRunArtifact(core_tests);
    test_step.dependOn(&run_core_tests.step);

    const patro_tests = b.addTest(.{ .root_module = patro });
    const run_patro_tests = b.addRunArtifact(patro_tests);
    test_step.dependOn(&run_patro_tests.step);

    const test_bin = b.addInstallFile(tests.getEmittedBin(), "bin/nepdate-tests");
    const test_bin_step = b.step("test-bin", "Build the integration test executable");
    test_bin_step.dependOn(&test_bin.step);

    const examples_module = b.createModule(.{
        .root_source_file = b.path("examples/examples.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "nepdate", .module = core },
            .{ .name = "nepdate_patro", .module = patro },
        },
    });
    const examples = b.addTest(.{ .root_module = examples_module });
    const run_examples = b.addRunArtifact(examples);
    const examples_step = b.step("docs-examples", "Run every example from the documentation");
    examples_step.dependOn(&run_examples.step);

    const check_step = b.step("check", "Compile the library, tests and examples");
    check_step.dependOn(&run_tests.step);
    check_step.dependOn(&run_examples.step);
    check_step.dependOn(&run_core_tests.step);
    check_step.dependOn(&run_patro_tests.step);

    const bench_module = b.createModule(.{
        .root_source_file = b.path("bench/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
        .imports = &.{
            .{ .name = "nepdate", .module = core },
            .{ .name = "nepdate_patro", .module = patro },
        },
    });
    const bench = b.addExecutable(.{ .name = "bench", .root_module = bench_module });
    b.installArtifact(bench);
    const run_bench = b.addRunArtifact(bench);
    run_bench.addPassthruArgs();
    const bench_step = b.step("bench", "Run B1 to B8");
    bench_step.dependOn(&run_bench.step);

    const cross_targets = [_][]const u8{
        "x86_64-linux-gnu",
        "aarch64-linux-gnu",
        "x86_64-macos",
        "aarch64-macos",
        "x86_64-windows-gnu",
        "aarch64-windows-gnu",
    };
    const cross_step = b.step("cross", "Cross-compile the core and patro for the supported systems");
    for (cross_targets) |query| {
        const cross = b.resolveTargetQuery(std.Target.Query.parse(.{ .arch_os_abi = query }) catch @panic("bad target"));
        const cross_core = b.createModule(.{
            .root_source_file = b.path("src/nepdate.zig"),
            .target = cross,
            .optimize = .ReleaseSafe,
            .link_libc = true,
        });
        addC(cross_core, b);
        const cross_patro = b.createModule(.{
            .root_source_file = b.path("src/patro.zig"),
            .target = cross,
            .optimize = .ReleaseSafe,
            .imports = &.{.{ .name = "nepdate", .module = cross_core }},
        });
        const cross_check = b.addTest(.{ .root_module = cross_patro });
        cross_step.dependOn(&cross_check.step);
    }

    const release_dry_run = b.addSystemCommand(&.{ "python", "tools/release_check.py", "--draft" });
    const release_step = b.step("release-dry-run", "Validate the manifests, changelog and source archive");
    release_step.dependOn(&release_dry_run.step);
}

fn addC(module: *std.Build.Module, b: *std.Build) void {
    module.addCSourceFiles(.{
        .files = &.{ "vendor/nepdate-c/nepdate.c", "vendor/nepdate-c/nepdate_patro.c" },
        .flags = c_flags,
    });
    module.addIncludePath(b.path("vendor/nepdate-c"));
}
