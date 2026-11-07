// zig fmt: off
const std = @import("std");

const printMod = @import("./printer.zig");
const Printer = printMod.Printer;
const Style = printMod.Style;
const zargs = @import("./zargunaught.zig");
const ArgParser = zargs.ArgParser;
const Option = zargs.Option;
const Command = zargs.Command;

// Lines are wrapped to this width.
const maxLineLength = 80;

// Command options sit this much further in than global options and commands.
const commandOptionIndent = 2;

/// The printed width of an option's names, e.g. `--name, -n`.
fn optionHelpNameLength(opt: *const Option) usize {
    // + 2 for the dashes
    var optLen = opt.longName.len + 2;
    if(opt.shortName.len > 0) {
        // 2 for the ', ' and 1 for the dash
        optLen += opt.shortName.len + 2 + 1;
    }

    return optLen;
}

/// The widest option or command name, counting a command option's extra
/// indent, so every description can start in the same column.
pub fn findMaxOptComLength(argsConf: *const ArgParser) usize
{
    var currMax: usize = 0;

    // Look at global options
    for(argsConf.options.data.items) |opt| {
        currMax = @max(optionHelpNameLength(&opt), currMax);
    }

    // Check the commands too
    for(argsConf.commands.data.items) |com| {
        currMax = @max(com.name.len, currMax);

        // Check the command options as well
        for(com.options.data.items) |opt| {
            currMax = @max(optionHelpNameLength(&opt) + commandOptionIndent, currMax);
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
    progDescription: Style,
    usage: Style,
    optionName: Style,
    commandName: Style,
    groupDescription: Style,
    groupName: Style,
    optionDash: Style,
    optionSeparator: Style,
    separator: Style,
    description: Style,
};

const CommandGroup = std.ArrayList(*Command);

pub const DefaultTheme: HelpTheme = .{
    .banner = .{ .fg = .BrightYellow, .bg = .Reset, .mod = .{ .bold = true } },
    .progDescription = .{ .fg = .BrightWhite, .bg = .Reset, .mod = .{ } },
    .usage = .{ .fg = .Reset , .bg = .Reset, .mod = .{ .italic = true } },
    .optionName = .{ .fg = .Cyan, .bg = . Reset, .mod = .{ .bold = true } },
    .commandName = .{ .fg = .BrightBlue, .bg = . Reset, .mod = .{ .bold = true } },
    .groupName = .{ .fg = .BrightGreen, .bg = . Reset, .mod = .{ .underline = true } },
    .groupDescription = .{ .fg = .White, .bg = . Reset, .mod = .{ .italic = true } },
    .optionDash = .{ .fg = .Cyan, .bg = . Reset, .mod = .{ .dim = true } },
    .optionSeparator = .{ .fg = .White, .bg = . Reset, .mod = .{ .dim = true } },
    .separator = .{ .fg = .White, .bg = . Reset, .mod = .{ .dim = true } },
    .description = .{ .fg = .Reset, .bg = . Reset, .mod = .{} },
};

pub const HelpFormatter = struct
{
    currLineLen: usize = 0,
    currIndentLevel: usize = 0,
    args: *const ArgParser,
    printer: Printer,
    theme: HelpTheme,
    alloc: std.mem.Allocator,
    commandGroups: std.StringHashMap(*CommandGroup),

    // Group names in the order their first command was defined, so the
    // help text follows the configuration instead of hash map order.
    groupOrder: std.ArrayList([]const u8),

    pub fn init(args: *const ArgParser, printer: Printer, theme: HelpTheme, alloc: std.mem.Allocator) !HelpFormatter
    {
        var formatter: HelpFormatter = .{
            .currLineLen = 0,
            .currIndentLevel = 0,
            .args = args,
            .printer = printer,
            .theme = theme,
            .alloc = alloc,
            .commandGroups = std.StringHashMap(*CommandGroup).init(alloc),
            .groupOrder = .empty,
        };
        errdefer formatter.deinit();

        for(0..args.commands.data.items.len) |idx| {
            const cmd: *Command = &args.commands.data.items[idx];
            const groupName: []const u8 = cmd.group orelse "";

            if(formatter.commandGroups.get(groupName)) |group| {
                try group.append(alloc, cmd);
                continue;
            }

            const group = try alloc.create(CommandGroup);
            group.* = .empty;
            formatter.commandGroups.put(groupName, group) catch |err| {
                alloc.destroy(group);
                return err;
            };
            try group.append(alloc, cmd);
            try formatter.groupOrder.append(alloc, groupName);
        }

        return formatter;
    }

    pub fn deinit(self: *HelpFormatter) void {
        var it = self.commandGroups.valueIterator();
        while (it.next()) |group| {
            group.*.deinit(self.alloc);
            self.alloc.destroy(group.*);
        }

        self.commandGroups.deinit();
        self.groupOrder.deinit(self.alloc);
    }

    // The column the ': ' before each description starts in.
    fn separatorColumn(maxOptComLen: usize) usize {
        return 2 + maxOptComLen + 1;
    }

    /// Pads from `currCol` to the separator column, then prints the
    /// separator and the word-wrapped description.
    fn printDescription(self: *HelpFormatter, description: []const u8, currCol: usize, maxOptComLen: usize) !void {
        const sepCol = separatorColumn(maxOptComLen);
        try self.theme.separator.set(self.printer);
        try self.printer.printNum(" ", sepCol - currCol);
        try self.printer.print(": ", .{});

        try self.theme.description.set(self.printer);
        const descCol = sepCol + 2;
        _ = try self.printer.printWrapped(description, descCol, descCol, maxLineLength);
    }

    fn printCommandGroup(self: *HelpFormatter, groupName: []const u8, group: *const CommandGroup, maxOptComLen: usize) !void {
        try self.theme.groupName.set(self.printer);

        if(std.mem.eql(u8, groupName, "")) {
            try self.printer.print("Commands", .{});
        }
        else {
            try self.printer.print("{s}", .{groupName});
        }

        try Style.reset(self.printer);

        // Print the group description if one exists.
        if(self.args.groupData.get(groupName)) |groupData| {
            if(groupData.description) |description| {
                try self.newLine();
                try self.theme.groupDescription.set(self.printer);
                try self.printer.print("  {s}", .{description});
                try self.newLine();
                try Style.reset(self.printer);
            }
        }

        // Iterate over the commands.
        for(group.items) |com| {

            try Style.reset(self.printer);
            try self.newLine();

            try self.theme.commandName.set(self.printer);
            try self.printer.print("  {s}", .{com.name});

            // Print out the command description if there is one.
            if(com.description) |description| {
                try self.printDescription(description, 2 + com.name.len, maxOptComLen);
            }

            if(com.options.data.items.len > 0) {
                try self.newLine();
            }

            // Check the command options as well
            for(com.options.data.items) |opt| {
                try Style.reset(self.printer);
                try self.printer.printNum(" ", 2 + commandOptionIndent);

                try self.theme.optionName.set(self.printer);
                const optLen = try self.optionHelpName(&opt);

                try self.printDescription(opt.description, 2 + commandOptionIndent + optLen, maxOptComLen);
                try self.newLine();
            }
        }

        try self.newLine();
    }

    pub fn printHelpText(self: *HelpFormatter) !void
    {
        const maxOptComLen = findMaxOptComLength(self.args);

        try self.newLine();
        try self.theme.banner.set(self.printer);
        if(self.args.parserOpts.banner) |banner| {
            try self.printer.print("{s}", .{banner});
        }
        else {
            try self.printer.print("{s}", .{self.args.name});
        }

        if(self.args.parserOpts.description) |description| {
            try self.theme.separator.set(self.printer);
            try self.printer.print(" - ", .{});

            try self.theme.progDescription.set(self.printer);
            try self.printer.print("{s}", .{description});
            try self.newLine();
        }

        try self.newLine();

        if(self.args.parserOpts.usage) |usage| {
            try self.theme.usage.set(self.printer);
            try self.printer.print("{s}", .{usage});

            try self.newLine();
            try self.newLine();
        }

        if(self.args.parserOpts.positionalDescription) |positionalDescription| {
            try self.theme.groupName.set(self.printer);
            try self.printer.print("Arguments", .{});
            try Style.reset(self.printer);
            try self.newLine();

            try self.theme.description.set(self.printer);
            try self.printer.print("  ", .{});
            _ = try self.printer.printWrapped(positionalDescription, 2, 2, maxLineLength);
            try Style.reset(self.printer);
            try self.newLine();
            try self.newLine();
        }

        if(self.args.options.data.items.len > 0) {
            try self.theme.groupName.set(self.printer);
            try self.printer.print("Global Options", .{});
            try Style.reset(self.printer);
            try self.newLine();

            // Look at global options
            for(self.args.options.data.items) |opt| {
                try Style.reset(self.printer);
                try self.printer.print("  ", .{});

                try self.theme.optionName.set(self.printer);
                const optLen = try self.optionHelpName(&opt);

                try self.printDescription(opt.description, 2 + optLen, maxOptComLen);
                try self.newLine();
            }

            try self.newLine();
        }

        for(self.groupOrder.items) |groupName| {
            const group = self.commandGroups.get(groupName).?;
            try self.printCommandGroup(groupName, group, maxOptComLen);
            try self.newLine();
        }

        try Style.reset(self.printer);
    }

    /// Prints `--name, -n` and returns its width.
    fn optionHelpName(self: *HelpFormatter, opt: *const Option) !usize
    {
        try self.theme.optionDash.set(self.printer);
        try self.optionDash(.Long);
        try self.theme.optionName.set(self.printer);
        try self.printer.print("{s}", .{opt.longName});

        if(opt.shortName.len > 0) {
            try self.theme.optionSeparator.set(self.printer);
            try self.printer.print(", ", .{});

            try self.theme.optionDash.set(self.printer);
            try self.optionDash(.Short);
            try self.theme.optionName.set(self.printer);
            try self.printer.print("{s}", .{opt.shortName});
        }

        return optionHelpNameLength(opt);
    }

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
};
