const std = @import("std");
const zargs = @import("zargunaught");
const testz = @import("testz");

fn configWithCommands(alloc: std.mem.Allocator) !zargs.ArgParser {
    return try zargs.ArgParser.init(alloc, .{
        .name = "helptest",
        .description = "Test config for help text generation with commands.",
        .commands = &.{
            .{ .name = "show", .description = "Show a thing." },
            .{ .name = "dump", .description = "Dump a thing.", .group = "extra" },
        },
    });
}

// HelpFormatter.init allocates a CommandGroup (an ArrayList(*Command)) per
// distinct command group; deinit previously only freed the surrounding
// hashmap, leaking every CommandGroup's backing array and the CommandGroup
// itself. Runs under the leak-checking DebugAllocator (see testz's "full"
// test signature), so this fails if that regresses.
pub fn helpFormatterWithCommandsDoesNotLeakTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try configWithCommands(alloc);
    defer parser.deinit();

    var printer = try zargs.print.Printer.memory(alloc);
    defer printer.deinit();

    var help = try zargs.help.HelpFormatter.init(&parser, printer, zargs.help.DefaultTheme, alloc);
    defer help.deinit();

    try help.printHelpText();
}
