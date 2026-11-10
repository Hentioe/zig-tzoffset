const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("zig_tzoffset", .{ .root_source_file = b.path("src/root.zig") });

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = b.standardTargetOptions(.{}),
    });
    const mod_tests = b.addTest(.{
        .root_module = test_mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
