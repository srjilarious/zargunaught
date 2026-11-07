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
    defer result.deinit(alloc);
    try compareStrArrays(expected[0..], result.args);
}

pub fn checkSimpleShellStringTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one two three";
    const expected = &[_][]const u8{ "one", "two", "three" };

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer result.deinit(alloc);
    try compareStrArrays(expected[0..], result.args);
}

pub fn checkDoubleQuotedShellStringTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one 'two three'";
    const expected = &[_][]const u8{ "one", "two three" };

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer result.deinit(alloc);
    try compareStrArrays(expected[0..], result.args);
}

pub fn checkSingleQuoteInsideDoubleQuotes(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    const base = "one 'two \"three\"'";
    const expected = &[_][]const u8{ "one", "two \"three\"" };

    const result = try zargs.utils.tokenizeShellString(alloc, base);
    defer result.deinit(alloc);
    try compareStrArrays(expected[0..], result.args);
}

fn expectTokens(alloc: std.mem.Allocator, input: []const u8, expected: []const []const u8) !void {
    const result = try zargs.utils.tokenizeShellString(alloc, input);
    defer result.deinit(alloc);
    try compareStrArrays(expected, result.args);
}

pub fn quotesJoinIntoOneWordTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try expectTokens(alloc, "--name=\"a b\" x", &.{ "--name=a b", "x" });
    try expectTokens(alloc, "a'b c'd", &.{"ab cd"});
    try expectTokens(alloc, "'it''s'", &.{"its"});
}

pub fn emptyQuotesMakeAnEmptyWordTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try expectTokens(alloc, "--beta \"\" ''", &.{ "--beta", "", "" });
}

pub fn whitespaceSeparatesWordsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try expectTokens(alloc, "  one\ttwo\n three  ", &.{ "one", "two", "three" });
    try expectTokens(alloc, "", &.{});
}

pub fn backslashEscapesTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try expectTokens(alloc, "a\\ b c\\\\", &.{ "a b", "c\\" });
    // Inside double quotes only \" and \\ are escapes.
    try expectTokens(alloc, "\"say \\\"hi\\\" \\n\"", &.{"say \"hi\" \\n"});
    // Inside single quotes nothing is.
    try expectTokens(alloc, "'a\\'", &.{"a\\"});
    // A backslash at the very end is kept.
    try expectTokens(alloc, "end\\", &.{"end\\"});
}

pub fn unterminatedQuoteTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try testz.expectError(zargs.utils.tokenizeShellString(alloc, "one \"two"), zargs.utils.TokenizeError.UnterminatedQuote);
    try testz.expectError(zargs.utils.tokenizeShellString(alloc, "'one"), zargs.utils.TokenizeError.UnterminatedQuote);
}

fn wrapped(alloc: std.mem.Allocator, value: []const u8, start: usize, indent: usize, max: usize) ![]u8 {
    var printer = try zargs.print.Printer.memory(alloc);
    defer printer.deinit();
    try printer.printNum(" ", start);
    _ = try printer.printWrapped(value, start, indent, max);
    return try alloc.dupe(u8, printer.array.writer.written());
}

fn expectWrapped(alloc: std.mem.Allocator, value: []const u8, start: usize, indent: usize, max: usize, expected: []const u8) !void {
    const text = try wrapped(alloc, value, start, indent, max);
    defer alloc.free(text);
    try testz.expectEqualStr(text, expected);
}

pub fn printWrappedBreaksBetweenWordsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    // Lines hold up to the maximum, and the space at a break is dropped.
    try expectWrapped(alloc, "aaa bbb ccc", 2, 2, 9, "  aaa bbb\n  ccc");
    try expectWrapped(alloc, "end.  Next", 0, 0, 20, "end.  Next");
}

pub fn printWrappedHyphenatesLongWordsTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    try expectWrapped(alloc, "abcdefghij", 0, 0, 5, "abcd-\nefgh-\nij");
    // Starting at or past the maximum used to underflow.
    try expectWrapped(alloc, "word", 10, 10, 8, "          word");
}

pub fn printWrappedKeepsNewlinesTest(io: std.Io, alloc: std.mem.Allocator) !void {
    _ = io;
    // Each newline starts an indented line, and no character after it is lost.
    try expectWrapped(alloc, "one\ntwo", 2, 2, 40, "  one\n  two");
}
