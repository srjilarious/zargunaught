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

pub fn checkSingleStringTest() !void {
    const base = "one_two_three";
    const expected = &[_][]const u8{"one_two_three"};

    const result = try zargs.utils.tokenizeShellString(std.heap.page_allocator, base);
    try compareStrArrays(expected[0..], result);
}

pub fn checkSimpleShellStringTest() !void {
    const base = "one two three";
    const expected = &[_][]const u8{ "one", "two", "three" };

    const result = try zargs.utils.tokenizeShellString(std.heap.page_allocator, base);
    try compareStrArrays(expected[0..], result);
}

pub fn checkDoubleQuotedShellStringTest() !void {
    const base = "one 'two three'";
    const expected = &[_][]const u8{ "one", "two three" };

    const result = try zargs.utils.tokenizeShellString(std.heap.page_allocator, base);
    try compareStrArrays(expected[0..], result);
}

pub fn checkSingleQuoteInsideDoubleQuotes() !void {
    const base = "one 'two \"three\"'";
    const expected = &[_][]const u8{ "one", "two \"three\"" };

    const result = try zargs.utils.tokenizeShellString(std.heap.page_allocator, base);
    try compareStrArrays(expected[0..], result);
}
