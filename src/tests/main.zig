const std = @import("std");
const zargs = @import("zargunaught");
const testz = @import("testz");

const Tests = testz.discoverTests(.{
    testz.Group{ .name = "Utility tests", .tag = "utils", .mod = @import("./utils_tests.zig") },
    testz.Group{ .name = "Options tests", .tag = "option", .mod = @import("./option_tests.zig") },
    testz.Group{ .name = "Command tests", .tag = "command", .mod = @import("./command_tests.zig") },
});

pub fn main() !void {
    const verbose = if (std.os.argv.len > 1 and std.mem.eql(u8, "verbose", std.mem.span(std.os.argv[1]))) true else false;

    _ = try testz.runTests(Tests, .{ .verbose = verbose });
}
