const std = @import("std");
const testz = @import("testz");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zargsMod = b.addModule("zargunaught", .{
        .root_source_file = b.path("src/zargunaught.zig"),
    });

    _ = addExample(b, target, optimize, "basic", "examples/basic.zig", zargsMod);

    // `addTestExe` wraps tests/main.zig in a root module that installs
    // testz's panic handler, so a panic during a captured test still prints.
    const testsMod = b.createModule(.{
        .root_source_file = b.path("tests/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    testsMod.addImport("zargunaught", zargsMod);
    const testsExe = testz.addTestExe(b, .{
        .target = target,
        .optimize = optimize,
        .testz_dep = b.dependency("testz", .{ .target = target, .optimize = optimize }),
        .name = "tests",
        .root_module = testsMod,
    });
    testsExe.use_llvm = true; // Force LLVM backend for debugging.
    addRunStep(b, testsExe, "tests");
}

fn addExample(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, comptime name: []const u8, root_src_path: []const u8, zargsMod: *std.Build.Module) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src_path),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("zargunaught", zargsMod);
    addRunStep(b, exe, name);
    return exe;
}

/// Installs `exe` and adds a `name` step that runs it with passthru args.
fn addRunStep(b: *std.Build, exe: *std.Build.Step.Compile, comptime name: []const u8) void {
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step(name, "Run " ++ name ++ " example");
    run_step.dependOn(&run_cmd.step);
}
