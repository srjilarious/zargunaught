// zig fmt: off
const std = @import("std");

const FilePrinterData = struct {
    alloc: std.mem.Allocator,
    file: std.fs.File,
    bufferWriter: std.io.BufferedWriter(4096, std.fs.File.Writer),
};

const ArrayPrinterData = struct {
    array: std.ArrayList(u8),
    bufferWriter: std.io.BufferedWriter(4096, std.ArrayList(u8).Writer),
    alloc: std.mem.Allocator,
};

// An adapter for printing either to an ArrayList or to a File like stdout.
pub const Printer = union(enum) {
    file: *FilePrinterData,
    array: *ArrayPrinterData,
    debug: bool,
    
    pub fn stdout(alloc: std.mem.Allocator) !Printer {
        var f = try alloc.create(FilePrinterData);
        f.alloc = alloc;
        f.file = std.io.getStdOut();
        f.bufferWriter = std.io.bufferedWriter(f.file.writer());
        return .{.file = f};
    }

    pub fn memory(alloc: std.mem.Allocator) !Printer {
        var a = try alloc.create(ArrayPrinterData);
        a.alloc = alloc;
        a.array = std.ArrayList(u8).init(alloc);
        a.bufferWriter = std.io.bufferedWriter(a.array.writer());
        return .{.array = a};
    }

    pub fn debug() Printer {
        return .{ .debug = true };
    }

    pub fn deinit(self: *Printer) void {
        switch(self.*) {
            .array => |arr| {
                arr.array.deinit();
                arr.alloc.destroy(self.array);
            },
            .file => |f| {
                f.alloc.destroy(self.file);
            },
            else => {}
        }
    }

    pub fn print(self: *Printer, comptime format: []const u8, args: anytype) anyerror!void
    {
        switch(self.*) {
            .array => |_| try self.array.bufferWriter.writer().print(format, args),
            .file => |_| try self.file.bufferWriter.writer().print(format, args),
            .debug => |_| std.debug.print(format, args),
        }
    }

    pub fn flush(self: *Printer) anyerror!void
    {
        switch(self.*) {
            .array => |_| try self.array.bufferWriter.flush(),
            .file => |_| try self.file.bufferWriter.flush(),
            .debug => {},
        }
    }
};
