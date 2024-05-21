// zig fmt: off
const std = @import("std");

pub const Color = enum {
    Reset,
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    Gray,
    BrightRed,
    BrightGreen,
    BrightYellow,
    BrightBlue,
    BrightMagenta,
    BrightCyan,
    BrightWhite
};

pub const TextStyle = packed struct {
    dim: bool = false,
    bold: bool = false,
    underline: bool = false,
    italic: bool = false,

    pub fn none(self: TextStyle) bool {
        const val: u4 = @bitCast(self);
        return val == 0;
    }
};

pub const Style = struct {
    fg: Color,
    bg: Color,
    mod: TextStyle,

    pub fn reset(printer: Printer) !void {
        try printer.print("\x1b[0m", .{});
    }

    pub fn set(self: *const Style, printer: Printer) !void {
        if(self.fg == .Reset or self.bg == .Reset or self.mod.none()) {
            try reset(printer);
        }
        
        if(self.mod.dim) {
            try printer.print("\x1b[2m", .{});
        }
        if(self.mod.bold) {
            try printer.print("\x1b[1m", .{});
        }
        if(self.mod.italic) {
            try printer.print("\x1b[3m", .{});
        }
        if(self.mod.underline) {
            try printer.print("\x1b[4m", .{});
        }

        switch(self.bg) 
        {
            .Black => try printer.print("\x1b[40m", .{}),
            .Red => try printer.print("\x1b[41m", .{}),
            .Green => try printer.print("\x1b[42m", .{}),
            .Yellow => try printer.print("\x1b[43m", .{}),
            .Blue => try printer.print("\x1b[44m", .{}),
            .Magenta => try printer.print("\x1b[45m", .{}),
            .Cyan => try printer.print("\x1b[46m", .{}),
            .White => try printer.print("\x1b[47m", .{}),
            .Gray => try printer.print("\x1b[100m", .{}),
            .BrightRed => try printer.print("\x1b[101m", .{}),
            .BrightGreen => try printer.print("\x1b[102m", .{}),
            .BrightYellow => try printer.print("\x1b[103m", .{}),
            .BrightBlue => try printer.print("\x1b[104m", .{}),
            .BrightMagenta => try printer.print("\x1b[105m", .{}),
            .BrightCyan => try printer.print("\x1b[106m", .{}),
            .BrightWhite => try printer.print("\x1b[107m", .{}),
            else => {},
        }

        switch(self.fg) 
        {
            .Black => try printer.print("\x1b[30m", .{}),
            .Red => try printer.print("\x1b[31m", .{}),
            .Green => try printer.print("\x1b[32m", .{}),
            .Yellow => try printer.print("\x1b[33m", .{}),
            .Blue => try printer.print("\x1b[34m", .{}),
            .Magenta => try printer.print("\x1b[35m", .{}),
            .Cyan => try printer.print("\x1b[36m", .{}),
            .White => try printer.print("\x1b[37m", .{}),
            .Gray => try printer.print("\x1b[90m", .{}),
            .BrightRed => try printer.print("\x1b[91m", .{}),
            .BrightGreen => try printer.print("\x1b[92m", .{}),
            .BrightYellow => try printer.print("\x1b[93m", .{}),
            .BrightBlue => try printer.print("\x1b[94m", .{}),
            .BrightMagenta => try printer.print("\x1b[95m", .{}),
            .BrightCyan => try printer.print("\x1b[96m", .{}),
            .BrightWhite => try printer.print("\x1b[97m", .{}),
            else => {},
        }
    }
};


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

    pub fn print(self: *const Printer, comptime format: []const u8, args: anytype) anyerror!void
    {
        switch(self.*) {
            .array => |_| try self.array.bufferWriter.writer().print(format, args),
            .file => |_| try self.file.bufferWriter.writer().print(format, args),
            .debug => |_| std.debug.print(format, args),
        }
    }

    pub fn flush(self: *const Printer) anyerror!void
    {
        switch(self.*) {
            .array => |_| try self.array.bufferWriter.flush(),
            .file => |_| try self.file.bufferWriter.flush(),
            .debug => {},
        }
    }
};
