// zig fmt: off
const std = @import("std");

const Printer = @import("./printer.zig").Printer;
const zargs = @import("./zargunaught.zig");
const ArgParser = zargs.ArgParser;
const Option = zargs.Option;
const Command = zargs.Command;

pub fn findMaxOptComLength(argsConf: *const ArgParser) usize
{
    var currMax: usize = 0;

    // Look at global options
    for(argsConf.options.data.items) |opt| {
        currMax = @max(opt.longName.len, currMax);
    }

    // Check the commands too
    for(argsConf.commands.data.items) |com| {
        currMax = @max(com.name.len, currMax);

        // Check the command options as well
        for(com.options.data.items) |opt| {
            currMax = @max(opt.name.len, currMax);
        }
    }

    return currMax;
}

const DashType = enum {
    Short,
    Long
};


pub const HelpFormatter = struct 
{
    currLineLen: usize = 0,
    currIndentLevel: usize = 0,
    args: *const ArgParser,
    printer: Printer,

    // A buffer used while printing so we can do word wrapping
    // properly.
    //buffer: [2048]u8,

    pub fn init(args: *const ArgParser, printer: Printer) HelpFormatter 
    {
        return .{
            .currLineLen = 0,
            .currIndentLevel = 0,
            .args = args,
            .printer = printer
        };
    }

    pub fn printHelpText(self: *HelpFormatter) !void
    {
        if(self.args.banner != null) {
            try self.printer.print("{?s}", .{self.args.banner});
        }
        else {
            try self.printer.print("{s}", .{self.args.name});
        }

        try self.newLine();

        // Look at global options
        for(self.args.options.data.items) |opt| {
            try self.printer.print("  ", .{});
            try self.optionHelpName(&opt);
            try self.printer.print(": {s}", .{opt.description});
            try self.newLine();
        }

        // Check the commands too
        for(self.args.commands.data.items) |com| {

            try self.printer.print("  {s}", .{com.name});
            if(com.description != null) {
                try self.printer.print(": {?s}", .{com.description});
                try self.newLine();
            }
            // Check the command options as well
            for(com.options.data.items) |opt| {
                try self.printer.print("    ", .{});
                try self.optionHelpName(&opt);
                try self.printer.print(": {s}", .{opt.description});
                try self.newLine();
            }
        }
    }

    // fn indent(level: usize) void
    // {
    //
    // }

    fn optionHelpName(self: *HelpFormatter, opt: *const Option) !void
    {
        try self.optionDash(.Long);
        try self.printer.print("{s}", .{opt.longName});

        if(opt.shortName.len > 0) {
            try self.printer.print(", ", .{});
            try self.optionDash(.Short);
            try self.printer.print("{s}", .{opt.shortName});
        }
    }

    // fn optionHelpNameLength(self: *HelpFormatter) usize
    // {
    //
    // }

    fn optionDash(self: *HelpFormatter, longDash: DashType) !void
    {
        switch(longDash) {
            .Long => try self.printer.print("--", .{}),
            .Short => try self.printer.print("-", .{})
        }
    }

    fn newLine(self: *HelpFormatter) !void
    {
        try self.printer.print("\n", .{});
        self.currLineLen = 0;
    }

    // fn optionHelpName(self: *HelpFormatter) void
    // {
    //
    // }


};
