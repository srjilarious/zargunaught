const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const zargsMod = b.addModule("zargunaught", .{
        .root_source_file = b.path("src/zargunaught.zig"),
    });

    _ = addExample(b, target, optimize, "basic", "examples/basic.zig", zargsMod);

    var testsExe = addExample(b, target, optimize, "tests", "tests/main.zig", zargsMod);
    const testzMod = b.dependency("testz", .{});
    testsExe.root_module.addImport("testz", testzMod.module("testz"));
}

fn addExample(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, comptime name: []const u8, root_src_path: []const u8, zargsMod: *std.Build.Module) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path(root_src_path),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zargunaught", zargsMod);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step(name, "Run " ++ name ++ " example");
    run_step.dependOn(&run_cmd.step);
    return exe;
}
