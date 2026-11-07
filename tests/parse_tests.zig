const std = @import("std");
const zargs = @import("zargunaught");
const testz = @import("testz");

// A parser covering flags, single and unlimited parameter options, a
// default that can be switched off, and an option whose own name starts
// with `no-`.
fn mixedConfig(alloc: std.mem.Allocator) !zargs.ArgParser {
    return try zargs.ArgParser.init(alloc, .{ .name = "Mixed options", .opts = &.{
        .{ .longName = "verbose", .shortName = "v", .maxOccurences = 5 },
        .{ .longName = "beta", .shortName = "b", .maxNumParams = 1 },
        .{ .longName = "gamma", .shortName = "g", .maxNumParams = null },
        .{ .longName = "syntax", .default = zargs.DefaultValue.set() },
        .{ .longName = "no-color" },
    } });
}

fn expectPositionals(args: *const zargs.ArgParserResult, expected: []const []const u8) !void {
    try testz.expectEqual(args.numPositional(), expected.len);
    for (expected, 0..) |e, i| {
        try testz.expectEqualStr(args.positional(i).?, e);
    }
}

// ----------------------------------------------------------------------------
// Option placement
// ----------------------------------------------------------------------------
pub fn optionsAfterPositionalsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "a", "-v", "b", "--beta", "1", "c" });
    defer args.deinit();

    try expectPositionals(&args, &.{ "a", "b", "c" });
    try testz.expectTrue(args.hasOption("verbose"));
    try testz.expectEqualStr(args.optionVal("beta").?, "1");
}

pub fn doubleDashEndsOptionsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "-v", "--", "-v", "--beta", "--" });
    defer args.deinit();

    try expectPositionals(&args, &.{ "-v", "--beta", "--" });
    try testz.expectEqual(args.option("verbose").?.numOccurences, 1);
    try testz.expectFalse(args.hasOption("beta"));
}

pub fn doubleDashEndsUnlimitedParamsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "-g", "x", "y", "--", "file" });
    defer args.deinit();

    try testz.expectEqual(args.option("gamma").?.values.items.len, 2);
    try expectPositionals(&args, &.{"file"});
}

pub fn loneDashIsPositionalTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "-", "-v" });
    defer args.deinit();

    try expectPositionals(&args, &.{"-"});
    try testz.expectTrue(args.hasOption("verbose"));
}

pub fn negativeNumbersTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    // A negative number is positional and doesn't end option parsing.
    {
        var args = try parser.parseArray(&.{ "-5", "-v" });
        defer args.deinit();
        try expectPositionals(&args, &.{"-5"});
        try testz.expectTrue(args.hasOption("verbose"));
        try testz.expectEqual((try args.positionalVal(i32, 0)).?, -5);
    }

    // It can also be an option's value.
    {
        var args = try parser.parseArray(&.{ "--beta", "-5" });
        defer args.deinit();
        try testz.expectEqual(try args.optionNumVal(i32, "beta"), -5);
        try testz.expectEqual(args.numPositional(), 0);
    }
}

pub fn stopAtFirstPositionalTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "Wrapper",
        .stopAtFirstPositional = true,
        .opts = &.{.{ .longName = "verbose", .shortName = "v" }},
    });
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "-v", "cmd", "-v", "--other" });
    defer args.deinit();

    try testz.expectEqual(args.option("verbose").?.numOccurences, 1);
    try expectPositionals(&args, &.{ "cmd", "-v", "--other" });
}

// ----------------------------------------------------------------------------
// Option values
// ----------------------------------------------------------------------------
pub fn flagsDoNotTakeParamsByDefaultTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Flags", .opts = &.{
        .{ .longName = "all", .shortName = "a" },
    } });
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "-a", "dir" });
    defer args.deinit();

    try testz.expectEqual(args.option("all").?.values.items.len, 0);
    try expectPositionals(&args, &.{"dir"});
}

pub fn emptyParamTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "--beta", "" });
    defer args.deinit();

    try testz.expectEqualStr(args.optionVal("beta").?, "");
}

pub fn attachedLongValueTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    {
        var args = try parser.parseArray(&.{ "--beta=1", "file" });
        defer args.deinit();
        try testz.expectEqualStr(args.optionVal("beta").?, "1");
        try expectPositionals(&args, &.{"file"});
    }

    // An attached value is the only value, even with no limit.
    {
        var args = try parser.parseArray(&.{ "--gamma=a=b", "file" });
        defer args.deinit();
        try testz.expectEqual(args.option("gamma").?.values.items.len, 1);
        try testz.expectEqualStr(args.optionVal("gamma").?, "a=b");
        try expectPositionals(&args, &.{"file"});
    }

    {
        var args = try parser.parseArray(&.{"--beta="});
        defer args.deinit();
        try testz.expectEqualStr(args.optionVal("beta").?, "");
    }

    try testz.expectError(parser.parseArray(&.{"--verbose=1"}), zargs.ParseError.OptionTakesNoParams);
    try testz.expectEqualStr(parser.failedArg.?, "--verbose=1");
}

pub fn attachedShortValueTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    {
        var args = try parser.parseArray(&.{"-b1"});
        defer args.deinit();
        try testz.expectEqualStr(args.optionVal("beta").?, "1");
    }

    // Flags first, then the value of the option that takes one.
    {
        var args = try parser.parseArray(&.{ "-vvbhello", "file" });
        defer args.deinit();
        try testz.expectEqual(args.option("verbose").?.numOccurences, 2);
        try testz.expectEqualStr(args.optionVal("beta").?, "hello");
        try expectPositionals(&args, &.{"file"});
    }

    try testz.expectError(parser.parseArray(&.{"-vx"}), zargs.ParseError.UnknownOption);
    try testz.expectEqualStr(parser.failedArg.?, "-vx");
}

pub fn minParamsCountPerOccurrenceTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Min params", .opts = &.{
        .{ .longName = "file", .shortName = "f", .minNumParams = 1, .maxNumParams = 1, .maxOccurences = null },
    } });
    defer parser.deinit();

    // The first --file having a value must not excuse the second.
    try testz.expectError(parser.parseArray(&.{ "--file", "a", "--file" }), zargs.ParseError.TooFewOptionParams);
}

// ----------------------------------------------------------------------------
// --no- prefix
// ----------------------------------------------------------------------------
pub fn noPrefixTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try mixedConfig(alloc);
    defer parser.deinit();

    // An option really named no-color is found by its own name.
    {
        var args = try parser.parseArray(&.{"--no-color"});
        defer args.deinit();
        try testz.expectTrue(args.hasOption("no-color"));
        try testz.expectTrue(args.hasOption("syntax"));
    }

    {
        var args = try parser.parseArray(&.{"--no-syntax"});
        defer args.deinit();
        try testz.expectFalse(args.hasOption("syntax"));
    }

    // The last of --name and --no-name wins.
    {
        var args = try parser.parseArray(&.{ "--syntax", "--no-syntax" });
        defer args.deinit();
        try testz.expectFalse(args.hasOption("syntax"));
    }
    {
        var args = try parser.parseArray(&.{ "--no-syntax", "--syntax" });
        defer args.deinit();
        try testz.expectTrue(args.hasOption("syntax"));
    }

    try testz.expectError(parser.parseArray(&.{"--no-nothing"}), zargs.ParseError.UnknownOption);
    try testz.expectEqualStr(parser.failedArg.?, "--no-nothing");
}

// ----------------------------------------------------------------------------
// Positional defaults and limits
// ----------------------------------------------------------------------------
pub fn defaultPositionalArgsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "Default positionals",
        .minNumPositionalArgs = 1,
        .defaultPositionalArgs = zargs.DefaultValue.param("."),
        .opts = &.{.{ .longName = "verbose", .shortName = "v" }},
    });
    defer parser.deinit();

    {
        var args = try parser.parseArray(&.{"-v"});
        defer args.deinit();
        try expectPositionals(&args, &.{"."});
    }

    {
        var args = try parser.parseArray(&.{ "a", "b" });
        defer args.deinit();
        try expectPositionals(&args, &.{ "a", "b" });
        try testz.expectEqual(args.positionals().len, 2);
    }
}

pub fn commandPositionalLimitsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "Command limits",
        .maxNumPositionalArgs = 1,
        .commands = &.{
            .{ .name = "copy", .minNumPositionalArgs = 2, .maxNumPositionalArgs = 2 },
            .{ .name = "show" },
        },
    });
    defer parser.deinit();

    {
        var args = try parser.parseArray(&.{ "copy", "a", "b" });
        defer args.deinit();
        try expectPositionals(&args, &.{ "a", "b" });
    }

    try testz.expectError(parser.parseArray(&.{ "copy", "a" }), zargs.ParseError.TooFewPositionalArguments);
    try testz.expectEqual(parser.failedArg, null);

    // show has no limits of its own, so the parser-wide maximum applies.
    try testz.expectError(parser.parseArray(&.{ "show", "a", "b" }), zargs.ParseError.TooManyPositionalArguments);
}

// ----------------------------------------------------------------------------
// Commands
// ----------------------------------------------------------------------------
fn commandConfig(alloc: std.mem.Allocator) !zargs.ArgParser {
    return try zargs.ArgParser.init(alloc, .{
        .name = "Commands",
        .opts = &.{.{ .longName = "verbose", .shortName = "v" }},
        .commands = &.{
            .{ .name = "fire", .opts = &.{.{ .longName = "into", .shortName = "i", .maxNumParams = 1 }} },
            .{ .name = "ice" },
        },
    });
}

pub fn optionsAroundCommandTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try commandConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "fire", "target", "-v", "-i", "stone" });
    defer args.deinit();

    try testz.expectEqualStr(args.command.?.name, "fire");
    try testz.expectTrue(args.hasOption("verbose"));
    try testz.expectEqualStr(args.optionVal("into").?, "stone");
    try expectPositionals(&args, &.{"target"});

    // A command's options aren't known before its name.
    try testz.expectError(parser.parseArray(&.{ "-i", "stone", "fire" }), zargs.ParseError.UnknownOption);
}

pub fn commandNameAfterPositionalIsPositionalTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try commandConfig(alloc);
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "fire", "ice" });
    defer args.deinit();

    try testz.expectEqualStr(args.command.?.name, "fire");
    try expectPositionals(&args, &.{"ice"});
}

pub fn commandConfigErrorsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try testz.expectError(zargs.ArgParser.init(alloc, .{ .commands = &.{ .{ .name = "a" }, .{ .name = "a" } } }), zargs.ParserConfigError.DuplicateCommandName);
    try testz.expectError(zargs.ArgParser.init(alloc, .{ .commands = &.{.{ .name = "" }} }), zargs.ParserConfigError.CommandNameMissing);
    try testz.expectError(zargs.ArgParser.init(alloc, .{ .groups = &.{.{ .name = "", .commands = &.{.{ .name = "a" }} }} }), zargs.ParserConfigError.CommandGroupNameMissing);

    // Global options stay usable after the command, so names can't clash.
    try testz.expectError(zargs.ArgParser.init(alloc, .{
        .opts = &.{.{ .longName = "verbose" }},
        .commands = &.{.{ .name = "a", .opts = &.{.{ .longName = "verbose" }} }},
    }), zargs.ParserConfigError.DuplicateOption);
}

pub fn commandListAddManyTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var list = zargs.CommandList.init(alloc);
    defer list.deinit();

    try list.addMany(&.{
        .{ .name = "a", .options = zargs.OptionList.init(alloc) },
        .{ .name = "b", .options = zargs.OptionList.init(alloc) },
    });
    try testz.expectEqualStr(list.find("b").?.name, "b");
}

// ----------------------------------------------------------------------------
// Option configuration
// ----------------------------------------------------------------------------
pub fn paramLimitConfigErrorsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    // Both are the mistake of wanting a value but leaving maxNumParams at 0.
    try testz.expectError(zargs.ArgParser.init(alloc, .{ .opts = &.{.{ .longName = "file", .minNumParams = 1 }} }), zargs.ParserConfigError.MinParamsExceedMax);
    try testz.expectError(zargs.ArgParser.init(alloc, .{ .opts = &.{.{ .longName = "file", .default = zargs.DefaultValue.param("x") }} }), zargs.ParserConfigError.DefaultParamsExceedMax);
    try testz.expectError(zargs.ArgParser.init(alloc, .{ .defaultPositionalArgs = zargs.DefaultValue.set() }), zargs.ParserConfigError.InvalidDefaultPositionalArgs);
}

pub fn manyOccurrencesTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Many", .opts = &.{
        .{ .longName = "verbose", .shortName = "v", .maxOccurences = null },
    } });
    defer parser.deinit();

    // More than a u8 can count.
    var stack: [301]u8 = @splat('v');
    stack[0] = '-';
    var args = try parser.parseArray(&.{&stack});
    defer args.deinit();
    try testz.expectEqual(args.option("verbose").?.numOccurences, 300);
}

pub fn longestShortNameWinsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Short names", .opts = &.{
        .{ .longName = "verbose", .shortName = "v", .maxOccurences = null },
        .{ .longName = "vexed", .shortName = "vx", .maxOccurences = null },
    } });
    defer parser.deinit();

    var args = try parser.parseArray(&.{ "-vx", "-vvx" });
    defer args.deinit();
    try testz.expectEqual(args.option("vexed").?.numOccurences, 2);
    try testz.expectEqual(args.option("verbose").?.numOccurences, 1);
}
