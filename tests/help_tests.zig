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

fn helpText(parser: *const zargs.ArgParser, alloc: std.mem.Allocator) ![]u8 {
    var printer = try zargs.print.Printer.memory(alloc);
    defer printer.deinit();

    var help = try zargs.help.HelpFormatter.init(parser, printer, zargs.help.DefaultTheme, alloc);
    defer help.deinit();

    try help.printHelpText();
    return try alloc.dupe(u8, printer.array.writer.written());
}

// Groups come out in the order they were configured, every ': ' lines up
// in one column, the positional description is printed, and a printer
// without color support gets no escape codes.
pub fn helpLayoutTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "layout",
        .positionalDescription = "<input> [output]",
        .opts = &.{
            .{ .longName = "verbose", .shortName = "v", .description = "More output." },
            .{ .longName = "x", .description = "Short one." },
        },
        .groups = &.{
            .{ .name = "zeta", .commands = &.{.{ .name = "last", .description = "Defined first." }} },
            .{ .name = "alpha", .commands = &.{.{ .name = "run", .description = "Runs.", .opts = &.{
                .{ .longName = "into", .shortName = "i", .description = "Target." },
            } }} },
        },
    });
    defer parser.deinit();

    const text = try helpText(&parser, alloc);
    defer alloc.free(text);

    try testz.expectTrue(std.mem.indexOf(u8, text, "\x1b") == null);
    try testz.expectTrue(std.mem.indexOf(u8, text, "Arguments\n  <input> [output]") != null);
    try testz.expectTrue(std.mem.indexOf(u8, text, "zeta").? < std.mem.indexOf(u8, text, "alpha").?);

    var column: ?usize = null;
    var lines = std.mem.splitScalar(u8, text, '\n');
    var count: usize = 0;
    while (lines.next()) |line| {
        const sep = std.mem.indexOf(u8, line, ": ") orelse continue;
        if (column) |c| try testz.expectEqual(sep, c) else column = sep;
        count += 1;
    }
    // Two global options, two commands, one command option.
    try testz.expectEqual(count, 5);
}
