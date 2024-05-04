const std = @import("std");
const zargs = @import("zargunaught");
// const fix = @import("fixtures.zig");
const testz = @import("testz");

pub fn anOptionMustHaveALongNameTest() !void {
    _ = zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "", .shortName = "d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.LongOptionNameMissing);
        return;
    };
    try testz.fail();
}

pub fn aLongOptionMustNotBeginWithANumberTest() !void {
    _ = zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "23delta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.OptionBeginsWithNumber);
        return;
    };
    try testz.fail();
}

pub fn aShortOptionMustNotBeginWithANumberTest() !void {
    _ = zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "23d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.OptionBeginsWithNumber);
        return;
    };

    try testz.fail();
}

pub fn aLongOptionMustBeUniqueTest() !void {
    _ = zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "beta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.DuplicateOption);
        return;
    };

    try testz.fail();
}

pub fn aShortOptionMustBeUniqueTest() !void {
    _ = zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Bad option configuration", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "b", .description = "", .maxNumParams = 1 },
    } }) catch |err| {
        try testz.expectEqual(err, zargs.ParserConfigError.DuplicateOption);
        return;
    };

    try testz.fail();
}

pub fn simpleLongOptionParseTest() !void {
    var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "d", .description = "", .maxNumParams = 1 },
    } });
    defer parser.deinit();

    const sysv = try zargs.utils.tokenizeShellString(std.heap.page_allocator, "--beta 123");
    defer std.heap.page_allocator.free(sysv);

    const args = try parser.parseArray(sysv);
    try testz.expectEqual(args.options.items.len, 1);
    const opt = args.options.items[0];
    try testz.expectEqual(opt.name, "beta");
    try testz.expectEqual(opt.values.items.len, 1);
    try testz.expectEqual(opt.values.items[0], "123");
}

