// zig fmt: off
const std = @import("std");
const zargs = @import("zargunaught");
// const fix = @import("fixtures.zig");
const testz = @import("testz");

// ----------------------------------------------------------------------------
fn simpleCommandConfig() !zargs.ArgParser 
{
    return try zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Simple command configuration", 
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
}

// ----------------------------------------------------------------------------
// Check a command can run with global option.
pub fn commandWithGlobalOptTest() !void {
    var parser = try simpleCommandConfig();
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(std.heap.page_allocator, "--beta 123 fire");
    defer std.heap.page_allocator.free(sysv);

    const args = try parser.parseArray(sysv);
    try testz.expectEqual(args.options.items.len, 1);
    try testz.expectEqualStr(args.options.items[0].name, "beta");

    try testz.expectTrue(args.command != null);
    try testz.expectEqualStr(args.command.?.name, "fire");
    
}

// ----------------------------------------------------------------------------
// Check a command can run with a local option.
pub fn commandWithCommandOptTest() !void {
    var parser = try simpleCommandConfig();
    defer parser.deinit();
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

// ----------------------------------------------------------------------------
// Check a command can run with a local option.
pub fn commandGroupsSimpleTest() !void {
    var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ 
        .name = "Simple command configuration", 
        .opts = &.{
            .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
            .{ .longName = "delta", .shortName = "d", .description = "", .maxNumParams = 1 },
        },
        .commands = &.{
            .{ .name = "test" },
            .{ .name = "transmogrify", .group = "experimental",
               .opts = &.{
                    .{ .longName = "into", .shortName = "i", .description = "", .maxNumParams = 1 }
                }
            }
        },
        .groups = &.{
            .{
                .name = "evocation",
                .commands = &.{ 
                    .{ .name = "fire" },
                    .{ .name = "ice" },
                    .{ .name = "thunder" }
                }
            }
        }
    });

    defer parser.deinit();

    try testz.expectEqual(parser.commands.data.items.len, 5);
    try testz.expectEqualStr(parser.commands.data.items[0].name, "test");
    try testz.expectEqualStr(parser.commands.data.items[1].name, "transmogrify");
    try testz.expectEqualStr(parser.commands.data.items[2].name, "fire");
    try testz.expectEqualStr(parser.commands.data.items[3].name, "ice");
    try testz.expectEqualStr(parser.commands.data.items[4].name, "thunder");

    const sysv = try zargs.utils.tokenizeShellString(std.heap.page_allocator, "--beta 123 thunder");
    defer std.heap.page_allocator.free(sysv);

    const args = try parser.parseArray(sysv);
    
    try testz.expectTrue(args.command != null);
    try testz.expectEqualStr(args.command.?.name, "thunder");

    try testz.expectEqual(args.options.items.len, 1);
    try testz.expectEqualStr(args.options.items[0].name, "beta");
    try testz.expectEqualStr(args.options.items[0].values.items[0], "123");
}


