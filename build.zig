const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zequality_dep = b.dependency("zequality", .{ .target = target, .optimize = optimize });
    const zequality_module = zequality_dep.module("zequality");

    const zmap_module = b.addModule("zmap", .{
        .root_source_file = b.path("src/zmap.zig"),
        .target = target,
        .optimize = optimize,
    });
    zmap_module.addImport("zequality", zequality_module);

    const docs_library = b.addLibrary(.{
        .name = "zmap",
        .root_module = zmap_module,
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_library.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate API documentation in zig-out/docs");
    docs_step.dependOn(&install_docs.step);

    const test_step = b.step("test", "Run all tests");

    const test_files = [_][]const u8{
        "tests/zmap_test.zig",
    };

    inline for (test_files) |test_file| {
        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
            }),
        });

        unit_tests.root_module.addImport("zmap", zmap_module);

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }

    b.default_step = test_step;
}
