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

