// zig fmt: off
const std = @import("std");
const zargs = @import("zargunaught");

const Option = zargs.Option;

pub fn main() !void {
    try basicOptionParsing();
}

fn basicOptionParsing() !void {
    std.debug.print("Basic option parsing...\n", .{});
    var parser = try zargs.ArgParser.init(
        std.heap.page_allocator, .{ 
            .name = "Test program", 
            .description = "A cool test program", 
            .opts = &[_]Option{
                Option{ .longName = "alpha", .shortName = "a", .description = "", .maxNumParams = 0 },
                Option{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
                Option{ .longName = "gamma", .shortName = "g", .description = "", .maxNumParams = -1 },
            } 
        });
    defer parser.deinit();

    var args = std.ArrayList([]const u8).init(std.heap.page_allocator);
    try args.append("--alpha");
    try args.append("--beta");
    try args.append("test!");

    _ = try parser.parse(args);
}
