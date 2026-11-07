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

fn helpText(parser: *const zargs.ArgParser, alloc: std.mem.Allocator, cmdName: ?[]const u8) ![]u8 {
    var printer = try zargs.print.Printer.memory(alloc);
    defer printer.deinit();

    var help = try zargs.help.HelpFormatter.init(parser, printer, zargs.help.DefaultTheme, alloc);
    defer help.deinit();

    if (cmdName) |name| {
        try help.printCommandHelp(parser.commands.find(name).?);
    } else {
        try help.printHelpText();
    }
    return try alloc.dupe(u8, printer.array.writer.written());
}

fn expectContains(text: []const u8, part: []const u8) !void {
    if (std.mem.indexOf(u8, text, part) == null) {
        std.debug.print("missing:\n{s}\nin:\n{s}\n", .{ part, text });
        try testz.fail();
    }
}

// Groups come out in the order they were configured, every ': ' lines up
// in one column, the arguments are listed, and a printer without color
// support gets no escape codes.
pub fn helpLayoutTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "layout",
        .positionals = &.{
            .{ .name = "input", .description = "Read from here." },
            .{ .name = "output", .description = "Write to here.", .optional = true },
        },
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

    const text = try helpText(&parser, alloc, null);
    defer alloc.free(text);

    try testz.expectTrue(std.mem.indexOf(u8, text, "\x1b") == null);
    try expectContains(text, "Usage: layout [options] [command] <input> [output]\n");
    try expectContains(text, "Arguments\n  input");
    try testz.expectTrue(std.mem.indexOf(u8, text, "zeta").? < std.mem.indexOf(u8, text, "alpha").?);

    var column: ?usize = null;
    var lines = std.mem.splitScalar(u8, text, '\n');
    var count: usize = 0;
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "Usage:")) continue;
        const sep = std.mem.indexOf(u8, line, ": ") orelse continue;
        if (column) |c| try testz.expectEqual(sep, c) else column = sep;
        count += 1;
    }
    // Two arguments, two global options, two commands, one command option.
    try testz.expectEqual(count, 7);
}

pub fn helpShowsValuesLimitsAndDefaultsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "values",
        .opts = &.{
            .{ .longName = "flag", .description = "A flag." },
            .{ .longName = "out", .shortName = "o", .description = "Output.", .minNumParams = 1, .maxNumParams = 1, .valueName = "file" },
            .{ .longName = "mode", .description = "Mode.", .maxNumParams = 1, .default = zargs.DefaultValue.param("fast") },
            .{ .longName = "pick", .description = "Picks.", .minNumParams = 1, .maxNumParams = 3 },
            .{ .longName = "any", .description = "Anything.", .maxNumParams = null },
            .{ .longName = "color", .description = "Colors.", .default = zargs.DefaultValue.set() },
            .{ .longName = "tags", .maxNumParams = 2, .default = zargs.DefaultValue.params(&.{ "a", "b" }) },
        },
    });
    defer parser.deinit();

    const text = try helpText(&parser, alloc, null);
    defer alloc.free(text);

    try expectContains(text, "  --flag ");
    try expectContains(text, "--out, -o <file> ");
    try expectContains(text, "--mode [value] ");
    try expectContains(text, ": Mode. (default: fast)");
    try expectContains(text, "--pick <value...> ");
    try expectContains(text, ": Picks. (1 to 3 values)");
    try expectContains(text, "--any [value...] ");
    try expectContains(text, ": Anything.\n");
    try expectContains(text, ": Colors. (on by default, --no-color turns it off)");
    try expectContains(text, ": (up to 2 values, default: a b)");
}

pub fn helpLongNameMovesDescriptionDownTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "long",
        .opts = &.{
            .{ .longName = "a", .description = "Short." },
            .{ .longName = "a-really-long-option-name", .description = "Long.", .maxNumParams = 1 },
        },
    });
    defer parser.deinit();

    const text = try helpText(&parser, alloc, null);
    defer alloc.free(text);

    // The column stops growing at its cap, and the long name's
    // description starts on the next line in that column.
    const sepCol = 2 + 24 + 1;
    const pad: [sepCol]u8 = @splat(' ');
    var expected: [80]u8 = undefined;
    const row = try std.fmt.bufPrint(&expected, "  --a-really-long-option-name [value]\n{s}: Long.", .{&pad});
    try expectContains(text, row);
}

pub fn commandHelpTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "prog",
        .opts = &.{.{ .longName = "verbose", .shortName = "v", .description = "More output." }},
        .commands = &.{
            .{
                .name = "copy",
                .description = "Copies files.",
                .positionals = &.{
                    .{ .name = "from", .description = "Source." },
                    .{ .name = "to", .description = "Destinations.", .repeat = true },
                },
                .opts = &.{.{ .longName = "force", .shortName = "f", .description = "Overwrite." }},
            },
            .{ .name = "other", .description = "Not shown." },
        },
    });
    defer parser.deinit();

    const text = try helpText(&parser, alloc, "copy");
    defer alloc.free(text);

    try expectContains(text, "Usage: prog [options] copy [options] <from> <to...>\n");
    try expectContains(text, "\nCopies files.\n");
    try expectContains(text, "Arguments\n  from");
    try expectContains(text, "Options\n  --force, -f");
    try expectContains(text, "Global Options\n  --verbose, -v");
    try testz.expectTrue(std.mem.indexOf(u8, text, "other") == null);

    // printHelp picks the command's help after parsing it.
    var args = try parser.parseArray(&.{ "copy", "a", "b" });
    defer args.deinit();

    var printer = try zargs.print.Printer.memory(alloc);
    defer printer.deinit();
    var help = try zargs.help.HelpFormatter.init(&parser, printer, zargs.help.DefaultTheme, alloc);
    defer help.deinit();
    try help.printHelp(&args);
    try testz.expectEqualStr(printer.array.writer.written(), text);
}

pub fn optionsHeadingWithoutCommandsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "plain",
        .opts = &.{.{ .longName = "verbose", .description = "More output." }},
    });
    defer parser.deinit();

    const text = try helpText(&parser, alloc, null);
    defer alloc.free(text);

    try expectContains(text, "\nOptions\n  --verbose");
    try testz.expectTrue(std.mem.indexOf(u8, text, "Global") == null);
}
