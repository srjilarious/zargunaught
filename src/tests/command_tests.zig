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

    // Check a command can run with global option.
    {
        const sysv = try zargs.utils.tokenizeShellString(std.heap.page_allocator, "--beta 123 fire");
        defer std.heap.page_allocator.free(sysv);

        const args = try parser.parseArray(sysv);
        try testz.expectEqual(args.options.items.len, 1);
        try testz.expectEqualStr(args.options.items[0].name, "beta");

        try testz.expectTrue(args.command != null);
        try testz.expectEqualStr(args.command.?.name, "fire");
    }

    // Check a command can run with a local option.
    {
        const sysv = try zargs.utils.tokenizeShellString(std.heap.page_allocator, "--beta 123 transmogrify -i stone");
        defer std.heap.page_allocator.free(sysv);

        const args = try parser.parseArray(sysv);
        
        try testz.expectTrue(args.command != null);
        try testz.expectEqualStr(args.command.?.name, "transmogrify");

        try testz.expectEqual(args.options.items.len, 2);
        try testz.expectEqualStr(args.options.items[0].name, "beta");
        try testz.expectEqualStr(args.options.items[0].values.items[0], "123");
        try testz.expectEqualStr(args.options.items[1].name, "into");
        try testz.expectEqualStr(args.options.items[1].values.items[0], "stone");

    }
}
