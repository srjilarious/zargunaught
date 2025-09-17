const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zargsMod = b.addModule("zargunaught", .{
        .root_source_file = b.path("src/zargunaught.zig"),
    });

    _ = addExample(b, target, optimize, "basic", "examples/basic.zig", zargsMod);

    var testsExe = addExample(b, target, optimize, "tests", "tests/main.zig", zargsMod);
    testsExe.use_llvm = true; // Force LLVM backend for debugging.
    const testzMod = b.dependency("testz", .{});
    testsExe.root_module.addImport("testz", testzMod.module("testz"));
}

fn addExample(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, comptime name: []const u8, root_src_path: []const u8, zargsMod: *std.Build.Module) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.addModule("main", .{
            .root_source_file = b.path(root_src_path),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("zargunaught", zargsMod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(name, "Run " ++ name ++ " example");
    run_step.dependOn(&run_cmd.step);
    return exe;
}
