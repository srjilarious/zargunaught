// zig fmt: off
const std = @import("std");
const zargs = @import("zargunaught");
// const fix = @import("fixtures.zig");
const testz = @import("testz");

// ----------------------------------------------------------------------------
pub fn anOptionMustHaveALongNameTest() !void {
    var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Simple command configuration", 
        .opts = &.{
            .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
            .{ .longName = "delta", .shortName = "d", .description = "", .maxNumParams = 1 },
        },
        .commands = &.{
            .{ .name = "fire" },
            .{ .name = "transmogrify", 
               .opts = &.{
                    .{ .longName = "into", .shortName = "i", .description = "", .maxNumParams = 1 }
                }
            }
        }
    }) ;
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(std.heap.page_allocator, "--beta 123 fire");
    defer std.heap.page_allocator.free(sysv);

    const args = try parser.parseArray(sysv);
    try testz.expectEqual(args.options.items.len, 1);
    try testz.expectTrue(args.command != null);
    try testz.expectEqualStr(args.command.?.name, "fire");
}
