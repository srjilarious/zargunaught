// zig fmt: off
const std = @import("std");

const printMod = @import("./printer.zig");
const Printer = printMod.Printer;
const Style = printMod.Style;
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

pub const HelpTheme = struct {
    banner: Style,
    optionName: Style,
    commandName: Style,
    groupName: Style,
    optionSeparator: Style,
    separator: Style,
    description: Style,
};

pub const DefaultTheme: HelpTheme = .{
    .banner = .{ .fg = .BrightBlue, .bg = .Reset, .mod = .{ .underline = true } },
    .optionName = .{ .fg = .Cyan, .bg = . Reset, .mod = .{} },
    .commandName = .{ .fg = .Yellow, .bg = . Reset, .mod = .{} },
    .groupName = .{ .fg = .Blue, .bg = . Reset, .mod = .{ .underline = true } },
    .optionSeparator = .{ .fg = .Cyan, .bg = . Reset, .mod = .{ .dim = true } },
    .separator = .{ .fg = .Reset, .bg = . Reset, .mod = .{ .dim = true } },
    .description = .{ .fg = .Reset, .bg = . Reset, .mod = .{} },
};

pub const HelpFormatter = struct 
{
    currLineLen: usize = 0,
    currIndentLevel: usize = 0,
    args: *const ArgParser,
    printer: Printer,
    theme: HelpTheme,

    // A buffer used while printing so we can do word wrapping
    // properly.
    //buffer: [2048]u8,

    pub fn init(args: *const ArgParser, printer: Printer, theme: HelpTheme) HelpFormatter 
    {
        return .{
            .currLineLen = 0,
            .currIndentLevel = 0,
            .args = args,
            .printer = printer,
            .theme = theme,
        };
    }

    pub fn printHelpText(self: *HelpFormatter) !void
    {
        try self.theme.banner.set(self.printer);
        if(self.args.banner != null) {
            try self.printer.print("{?s}", .{self.args.banner});
        }
        else {
            try self.printer.print("{s}", .{self.args.name});
        }

        try self.newLine();
        try self.newLine();

        try self.theme.groupName.set(self.printer);
        try self.printer.print("Global Options", .{});
        try Style.reset(self.printer);
        try self.newLine();

        // Look at global options
        for(self.args.options.data.items) |opt| {
            try Style.reset(self.printer);
            try self.printer.print("  ", .{});

            try self.theme.optionName.set(self.printer);
            try self.optionHelpName(&opt);

            try self.theme.separator.set(self.printer);
            try self.printer.print(": ", .{});

            try self.theme.description.set(self.printer);
            try self.printer.print("{s}", .{opt.description});
            try self.newLine();
        }

        try self.newLine();
        try self.theme.groupName.set(self.printer);
        try self.printer.print("Commands", .{});
        try Style.reset(self.printer);

        // Check the commands too
        for(self.args.commands.data.items) |com| {

            try Style.reset(self.printer);
            try self.newLine();

            try self.theme.commandName.set(self.printer);
            try self.printer.print("  {s}", .{com.name});

            // Print out the command description if there is one.
            if(com.description != null) {
                try self.theme.separator.set(self.printer);
                try self.printer.print(": ", .{});

                try self.theme.description.set(self.printer);
                try self.printer.print("{?s}", .{com.description});
                try self.newLine();
            }

            // Check the command options as well
            for(com.options.data.items) |opt| {
                try Style.reset(self.printer);
                try self.printer.print("    ", .{});

                try self.theme.optionName.set(self.printer);
                try self.optionHelpName(&opt);

                try self.theme.separator.set(self.printer);
                try self.printer.print(": ", .{});

                try self.theme.description.set(self.printer);
                try self.printer.print("{s}", .{opt.description});
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
        try self.theme.optionName.set(self.printer);
        try self.optionDash(.Long);
        try self.printer.print("{s}", .{opt.longName});

        if(opt.shortName.len > 0) {
            try self.theme.optionSeparator.set(self.printer);
            try self.printer.print(", ", .{});
        
            try self.theme.optionName.set(self.printer);
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
