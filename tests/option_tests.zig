const std = @import("std");
const zargs = @import("zargunaught");
const testz = @import("testz");

// ----------------------------------------------------------------------------
// Configuration Tests
// ----------------------------------------------------------------------------
pub fn anOptionMustHaveALongNameTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = zargs.ArgParser.init(alloc, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "", .shortName = "d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.LongOptionNameMissing);
        return;
    };

    try testz.fail();
}

pub fn aLongOptionMustNotBeginWithANumberTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = zargs.ArgParser.init(alloc, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "23delta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.OptionBeginsWithNumber);
        return;
    };
    try testz.fail();
}

pub fn aShortOptionMustNotBeginWithANumberTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = zargs.ArgParser.init(alloc, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "23d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.OptionBeginsWithNumber);
        return;
    };

    try testz.fail();
}

pub fn aLongOptionMustBeUniqueTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = zargs.ArgParser.init(alloc, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "beta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.DuplicateOption);
        return;
    };

    try testz.fail();
}

pub fn aShortOptionMustBeUniqueTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    _ = zargs.ArgParser.init(alloc, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "b", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.DuplicateOption);
        return;
    };

    try testz.fail();
}

// ----------------------------------------------------------------------------
// Parsing Tests
// ----------------------------------------------------------------------------
pub fn simpleLongOptionParseTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } });
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(alloc, "--beta 123");
    defer alloc.free(sysv);

    var args = try parser.parseArray(sysv);
    defer args.deinit();
    try testz.expectEqual(args.options.items.len, 1);
    const opt = args.options.items[0];
    try testz.expectEqualStr(opt.name, "beta");
    try testz.expectEqual(opt.values.items.len, 1);
    try testz.expectEqualStr(opt.values.items[0], "123");
}

pub fn simpleShortOptionParseTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } });
    defer parser.deinit();

    // Test first short option
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-b 123");
        defer alloc.free(sysv);

        var args = parser.parseArray(sysv) catch |err| {
            try testz.failWith(err);
            return;
        };
        defer args.deinit();

        try testz.expectEqual(args.options.items.len, 1);
        const opt = args.options.items[0];
        try testz.expectEqualStr(opt.name, "beta");
        try testz.expectEqual(opt.values.items.len, 1);
        try testz.expectEqualStr(opt.values.items[0], "123");
    }

    // Test second short option
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-d 234");
        defer alloc.free(sysv);

        var args = parser.parseArray(sysv) catch |err| {
            try testz.failWith(err);
            return;
        };

        defer args.deinit();

        try testz.expectEqual(args.options.items.len, 1);
        const opt = args.options.items[0];
        try testz.expectEqualStr(opt.name, "delta");
        try testz.expectEqual(opt.values.items.len, 1);
        try testz.expectEqualStr(opt.values.items[0], "234");
    }
}

pub fn testMinParams(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "delta", .shortName = "d", .description = "", .minNumParams = 1, .default = zargs.DefaultValue.param("boop") },
    } });
    defer parser.deinit();

    // Test with too few params for delta
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--delta");
        defer alloc.free(sysv);

        if (parser.parseArray(sysv)) |_| {
            try testz.failWith("Expected a parsing error!");
        } else |err| {
            try testz.expectEqual(zargs.ParseError.TooFewOptionParams, err);
        }
    }

    // Test that with min params satisfied that things work.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--delta bop!");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);

        const opt = args.options.items[0];
        try testz.expectEqualStr(opt.name, "delta");
        try testz.expectEqual(opt.values.items.len, 1);
        try testz.expectEqualStr(opt.values.items[0], "bop!");
    }

    // Test that a default option is ok.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);

        const opt = args.options.items[0];
        try testz.expectEqualStr(opt.name, "delta");
        try testz.expectEqual(opt.values.items.len, 1);
        try testz.expectEqualStr(opt.values.items[0], "boop");
    }
}

pub fn checkDefaultValues(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .default = zargs.DefaultValue.param("blah") },
        .{ .longName = "delta", .shortName = "d", .description = "", .default = zargs.DefaultValue.param("boop") },
    } });
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(alloc, "");
    defer alloc.free(sysv);

    var args = try parser.parseArray(sysv);
    defer args.deinit();
    try testz.expectEqual(args.options.items.len, 2);

    const opt = args.options.items[0];
    try testz.expectEqualStr(opt.name, "beta");
    try testz.expectEqual(opt.values.items.len, 1);
    try testz.expectEqualStr(opt.values.items[0], "blah");

    const opt2 = args.options.items[1];
    try testz.expectEqualStr(opt2.name, "delta");
    try testz.expectEqual(opt2.values.items.len, 1);
    try testz.expectEqualStr(opt2.values.items[0], "boop");
}

pub fn checkDefaultMultipleValues(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .default = zargs.DefaultValue.params(&.{ "blah", "foo" }) },
        .{ .longName = "delta", .shortName = "d", .description = "", .default = zargs.DefaultValue.params(&.{ "boop", "blop", "bleep" }) },
    } });
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(alloc, "");
    defer alloc.free(sysv);

    var args = try parser.parseArray(sysv);
    defer args.deinit();
    try testz.expectEqual(args.options.items.len, 2);

    const opt = args.options.items[0];
    try testz.expectEqualStr(opt.name, "beta");
    try testz.expectEqual(opt.values.items.len, 2);
    try testz.expectEqualStr(opt.values.items[0], "blah");
    try testz.expectEqualStr(opt.values.items[1], "foo");

    const opt2 = args.options.items[1];
    try testz.expectEqualStr(opt2.name, "delta");
    try testz.expectEqual(opt2.values.items.len, 3);
    try testz.expectEqualStr(opt2.values.items[0], "boop");
    try testz.expectEqualStr(opt2.values.items[1], "blop");
    try testz.expectEqualStr(opt2.values.items[2], "bleep");
}

pub fn checkDefaultOptionsWithoutParams(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "" },
        .{ .longName = "delta", .shortName = "d", .description = "", .default = zargs.DefaultValue.set() },
    } });
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(alloc, "");
    defer alloc.free(sysv);

    var args = try parser.parseArray(sysv);
    defer args.deinit();
    try testz.expectEqual(args.options.items.len, 1);

    const opt = args.options.items[0];
    try testz.expectEqualStr(opt.name, "delta");
    try testz.expectEqual(opt.values.items.len, 0);
}

pub fn alllowANoPrefixOnOptions(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .default = zargs.DefaultValue.set() },
        .{ .longName = "delta", .shortName = "d", .description = "", .default = zargs.DefaultValue.set() },
    } });
    defer parser.deinit();

    // By default we should set both of our options above.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 2);
    }

    // Turn off both options with a `no-` prefix.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--no-beta --no-delta");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 0);
    }

    // Check again but with just one option turned off.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--no-beta");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);

        const opt = args.options.items[0];
        try testz.expectEqualStr(opt.name, "delta");
        try testz.expectEqual(opt.values.items.len, 0);
    }
}

pub fn testTooFewOrTooManyPositionalArgs(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{
        .name = "Simple options",
        .minNumPositionalArgs = 1,
        .maxNumPositionalArgs = 2,
    });
    defer parser.deinit();

    // Check that too few args is an error.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "");
        defer alloc.free(sysv);

        const args = parser.parseArray(sysv);
        if (args != zargs.ParseError.TooFewPositionalArguments) {
            try testz.failWith("Expected a too few positional args error!");
        }
    }

    // Check that enough args is not an error.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "one two");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.positional.items.len, 2);
    }

    // Check that too many args is an error.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "one two three");
        defer alloc.free(sysv);

        const args = parser.parseArray(sysv);
        if (args != zargs.ParseError.TooManyPositionalArguments) {
            try testz.failWith("Expected a too many positional args error!");
        }
    }
}

pub fn testMultipleOptionInstanceParams(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "file", .shortName = "f", .description = "files", .maxOccurences = 4 },
        .{ .longName = "delta", .shortName = "d", .description = "", .maxOccurences = 2 },
    } });
    defer parser.deinit();

    // We expect multiple occurences to add to the existing list of parameters in an option result.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--file one --file two --file three");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);
        const optResult = args.option("file");
        try testz.expectEqual(optResult.?.values.items.len, 3);
        try testz.expectEqual(optResult.?.numOccurences, 3);
        try testz.expectEqualStr(optResult.?.values.items[0], "one");
        try testz.expectEqualStr(optResult.?.values.items[1], "two");
        try testz.expectEqualStr(optResult.?.values.items[2], "three");
    }

    // Mixing short and long names should be the same.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--file one -f two -f three");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);
        const optResult = args.option("file");
        try testz.expectEqual(optResult.?.values.items.len, 3);
        try testz.expectEqual(optResult.?.numOccurences, 3);
        try testz.expectEqualStr(optResult.?.values.items[0], "one");
        try testz.expectEqualStr(optResult.?.values.items[1], "two");
        try testz.expectEqualStr(optResult.?.values.items[2], "three");
    }

    // Mixing other options in the middle should also be fine.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "--file one -d -f two -d -f three");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 2);
        const optResult = args.option("file");
        try testz.expectEqual(optResult.?.numOccurences, 3);
        try testz.expectEqual(optResult.?.values.items.len, 3);
        try testz.expectEqualStr(optResult.?.values.items[0], "one");
        try testz.expectEqualStr(optResult.?.values.items[1], "two");
        try testz.expectEqualStr(optResult.?.values.items[2], "three");
    }
}

pub fn testOptionStacking(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "verbose", .shortName = "v", .description = "log verbosity", .maxOccurences = 5 },
        .{ .longName = "delta", .shortName = "d", .description = "" },
    } });
    defer parser.deinit();

    // Check that we can still use a single occurence of a stacked option.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-v");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 1);
    }

    // Check that we can see multiple occurences of stacked option.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-vvvv");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 4);
    }

    // Check that we can see max occurences of stacked option.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-vvvvv");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 1);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 5);
    }

    // Check that we can see an error over max occurences of stacked option.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-vvvvvv");
        defer alloc.free(sysv);

        const args = parser.parseArray(sysv);
        try testz.expectError(args, error.TooManyOptionOccurences);
    }
}

pub fn testOptionStackingWithLastParams(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{
            .longName = "verbose",
            .shortName = "v",
            .description = "log verbosity",
            .maxOccurences = 5,
            .maxNumParams = 0,
        },
        .{
            .longName = "gamma",
            .shortName = "g",
            .description = "",
        },
        .{
            .longName = "delta",
            .shortName = "d",
            .description = "",
            .maxNumParams = 3,
        },
    } });
    defer parser.deinit();

    // Check that we can see multiple occurences of stacked option and another option as well.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-dvvv");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 2);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 3);

        const deltaResult = args.option("delta");
        try testz.expectEqual(deltaResult.?.values.items.len, 0);
    }

    // Check that we can see multiple occurences of stacked option and another option as well.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-dgvv");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 3);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 2);

        const gammaResult = args.option("gamma");
        try testz.expectEqual(gammaResult.?.values.items.len, 0);

        const deltaResult = args.option("delta");
        try testz.expectEqual(deltaResult.?.values.items.len, 0);
    }

    // Check that we can see multiple occurences of stacked options, extra params after stacks show
    // as positional.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-vvgvvd one two three");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();
        try testz.expectEqual(args.options.items.len, 3);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 4);

        const gammaResult = args.option("gamma");
        try testz.expectEqual(gammaResult.?.values.items.len, 0);

        const deltaResult = args.option("delta");
        try testz.expectEqual(deltaResult.?.values.items.len, 0);
        try testz.expectEqual(args.positional.items.len, 3);
        try testz.expectEqualStr(args.positional.items[0], "one");
        try testz.expectEqualStr(args.positional.items[1], "two");
        try testz.expectEqualStr(args.positional.items[2], "three");
    }
}

pub fn testOptionStackingWithOptionsWithoutShortName(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    var parser = try zargs.ArgParser.init(alloc, .{ .name = "Simple options", .opts = &.{
        .{
            .longName = "gamma",
            .shortName = "",
            .description = "",
        },
        .{
            .longName = "verbose",
            .shortName = "v",
            .description = "log verbosity",
            .maxOccurences = 5,
            .maxNumParams = 0,
        },
        .{
            .longName = "delta",
            .shortName = "",
            .description = "",
            .maxNumParams = 3,
        },
    } });
    defer parser.deinit();

    // There was a bug where if an early option in the arg parser didn't have a short name,
    // the option stacking would never end until overflowing the number of occurences.
    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-v");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();

        try testz.expectEqual(args.options.items.len, 1);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 1);
    }

    {
        const sysv = try zargs.utils.tokenizeShellString(alloc, "-vvv --delta");
        defer alloc.free(sysv);

        var args = try parser.parseArray(sysv);
        defer args.deinit();

        try testz.expectEqual(args.options.items.len, 2);
        const optResult = args.option("verbose");
        try testz.expectEqual(optResult.?.numOccurences, 3);
        const deltaResult = args.option("delta");
        try testz.expectEqual(deltaResult.?.numOccurences, 1);
    }
}
