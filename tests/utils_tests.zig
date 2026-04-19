const std = @import("std");
const zargs = @import("zargunaught");
// const fix = @import("fixtures.zig");
const testz = @import("testz");

fn compareStrArrays(expected: []const []const u8, result: []const []const u8) !void {
    try testz.expectEqual(expected.len, result.len);
    for (0..expected.len) |idx| {
        try testz.expectEqualStr(expected[idx], result[idx]);
    }
}

pub fn checkSingleStringTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one_two_three";
    const expected = &[_][]const u8{"one_two_three"};

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer alloc.free(result);
    try compareStrArrays(expected[0..], result);
}

pub fn checkSimpleShellStringTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one two three";
    const expected = &[_][]const u8{ "one", "two", "three" };

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer alloc.free(result);
    try compareStrArrays(expected[0..], result);
}

pub fn checkDoubleQuotedShellStringTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one 'two three'";
    const expected = &[_][]const u8{ "one", "two three" };

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer alloc.free(result);
    try compareStrArrays(expected[0..], result);
}

pub fn checkSingleQuoteInsideDoubleQuotes(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one 'two \"three\"'";
    const expected = &[_][]const u8{ "one", "two \"three\"" };

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer alloc.free(result);
    try compareStrArrays(expected[0..], result);
}
