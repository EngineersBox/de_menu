const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    const known_folders = b.dependency("known_folders", .{
        .target = target,
        .optimize = optimize,
    });
    // Mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
    // const microwave = b.dependency("microwave", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    const fontconfig = b.dependency(
        "fontconfig",
        .{ .target = target, .optimize = optimize },
    );

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "de_menu",
        .root_module = exe_mod,
    });

    exe.linkLibrary(raylib.artifact("raylib"));
    exe.linkSystemLibrary("iconv");
    exe.linkLibrary(fontconfig.artifact("fontconfig"));
    exe.root_module.addImport("raylib", raylib.module("raylib"));
    exe.root_module.addImport("raygui", raylib.module("raygui"));
    exe.root_module.addImport("clap", clap.module("clap"));
    exe.root_module.addImport("known-folders", known_folders.module("known-folders"));
    // exe.root_module.addImport("microwave", microwave.module("microwave"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
