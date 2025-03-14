const std = @import("std");
const ArgQueue = std.DoublyLinkedList([]const u8);

pub const utils = @import("./utils.zig");
pub const help = @import("./helptext.zig");
pub const print = @import("./printer.zig");

pub const ParserConfigError = error{
    LongOptionNameMissing,
    OptionBeginsWithNumber,
    DuplicateOption,
    CommandNameMissing,
    DuplicateCommandName,
    CommandGroupNameMissing,
};

pub const ParseError = error{
    UnknownOption,
    TooFewOptionParams,
    TooFewPositionalArguments,
    TooManyPositionalArguments,
};

// Used to provide a list of parameters to an option when it takes
// multiple parameters.
const DefaultParameters = struct { values: []const []const u8 };

// Used to provide a single of parameter to an option when it takes
// one parameter.
const DefaultParameter = struct { value: []const u8 };

// Used to set an option to default on when it has no parameters.
const DefaultOption = struct { on: bool = true };

pub const DefaultValue = union(enum) {
    _params: DefaultParameters,
    _param: DefaultParameter,
    _set: DefaultOption,

    pub fn params(vals: []const []const u8) DefaultValue {
        return DefaultValue{ ._params = .{ .values = vals } };
    }

    pub fn param(val: []const u8) DefaultValue {
        return DefaultValue{ ._param = .{ .value = val } };
    }

    pub fn set() DefaultValue {
        return DefaultValue{ ._set = .{ .on = true } };
    }
};

pub const Option = struct {
    longName: []const u8,
    shortName: []const u8 = "",
    description: []const u8 = "",
    maxOccurences: ?u8 = null,
    minNumParams: ?u8 = null,
    maxNumParams: ?u8 = null,
    default: ?DefaultValue = null,
};

pub const OptionResult = struct {
    name: []const u8,
    values: std.ArrayList([]const u8),
    numOccurences: u8,

    pub fn init(name: []const u8) OptionResult {
        // TODO: fix allocator.
        return .{
            .name = name,
            .values = std.ArrayList([]const u8).init(std.heap.page_allocator),
            .numOccurences = 0,
        };
    }

    pub fn deinit(self: *OptionResult) void {
        self.values.deinit();
    }
};

const OptionFindResult = struct {
    opt: ?Option,
    // The remainder of the short option text after finding a matching short option name.
    remaining: []const u8,
};

pub const OptionList = struct {
    data: std.ArrayList(Option),

    pub fn init(allocator: std.mem.Allocator) OptionList {
        const options = std.ArrayList(Option).init(allocator);
        return OptionList{ .data = options };
    }

    pub fn deinit(self: OptionList) void {
        self.data.deinit();
    }

    pub fn addOptions(self: *OptionList, opts: []const Option) ParserConfigError!void {
        for (opts) |o| {
            try self.addOption(o);
        }
    }

    pub fn addOption(self: *OptionList, opt: Option) ParserConfigError!void {
        if (opt.longName.len == 0) {
            return ParserConfigError.LongOptionNameMissing;
        }

        if (std.ascii.isDigit(opt.longName[0])) {
            return ParserConfigError.OptionBeginsWithNumber;
        }

        if (opt.shortName.len > 0 and std.ascii.isDigit(opt.shortName[0])) {
            return ParserConfigError.OptionBeginsWithNumber;
        }

        for (self.data.items) |o| {
            if (std.mem.eql(u8, opt.longName, o.longName)) {
                return ParserConfigError.DuplicateOption;
            }

            if (opt.shortName.len > 0 and std.mem.eql(u8, opt.shortName, o.shortName)) {
                return ParserConfigError.DuplicateOption;
            }
        }

        self.data.append(opt) catch unreachable;
    }

    pub fn findLongOption(self: *const OptionList, optName: []const u8) ?Option {
        for (self.data.items) |opt| {
            if (std.mem.eql(u8, opt.longName, optName)) {
                return opt;
            }
        }

        return null;
    }

    pub fn findShortOption(self: *const OptionList, optName: []const u8) OptionFindResult {
        for (self.data.items) |opt| {
            // Allow short option names to stack.

            if (opt.shortName.len > 0 and std.mem.startsWith(u8, optName, opt.shortName)) {
                return .{ .opt = opt, .remaining = optName[opt.shortName.len..] };
            }
        }

        return .{ .opt = null, .remaining = optName };
    }
};

pub const Command = struct { name: []const u8, description: ?[]const u8 = null, group: ?[]const u8 = null, options: OptionList };

pub const CommandList = struct {
    data: std.ArrayList(Command),

    pub fn init(allocator: std.mem.Allocator) CommandList {
        const data = std.ArrayList(Command).init(allocator);
        return CommandList{ .data = data };
    }

    pub fn deinit(self: CommandList) void {
        for (self.data.items) |cmd| {
            cmd.options.deinit();
        }

        self.data.deinit();
    }

    pub fn addMany(self: *CommandList, cmds: []const Command) ParserConfigError!void {
        for (cmds) |c| {
            try self.add(c);
        }
    }

    pub fn add(self: *CommandList, cmd: Command) ParserConfigError!void {
        if (cmd.name.len == 0) {
            return ParserConfigError.CommandNameMissing;
        }

        for (self.data.items) |c| {
            if (std.mem.eql(u8, cmd.name, c.name)) {
                return ParserConfigError.DuplicateOption;
            }
        }

        self.data.append(cmd) catch unreachable;
    }

    pub fn find(self: *CommandList, cmdName: []const u8) ?Command {
        for (self.data.items) |cmd| {
            if (std.mem.eql(u8, cmd.name, cmdName)) {
                return cmd;
            }
        }

        return null;
    }
};

/// The configuration options for a command used when setting
/// up the ArgParser.
pub const CommandOpt = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    group: ?[]const u8 = null,
    opts: ?[]const Option = null,
};

/// The parameters for a named group of commands.  This is just
/// a convenience wrapper for specifying the same group name on
/// each command diretly.
pub const GroupOpt = struct {
    name: []const u8,
    commands: []const CommandOpt,
    description: ?[]const u8 = null,
};

/// The top level configuration parameters for an ArgParser.
pub const ArgParserOpts = struct {
    name: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    description: ?[]const u8 = null,
    usage: ?[]const u8 = null,
    positionalDescription: ?[]const u8 = null,
    minNumPositionalArgs: ?u8 = null,
    maxNumPositionalArgs: ?u8 = null,
    defaultPositionalArgs: ?DefaultValue = null,
    opts: ?[]const Option = null,
    commands: ?[]const CommandOpt = null,
    groups: ?[]const GroupOpt = null,
};

pub const GroupData = struct {
    description: ?[]const u8 = null,
};

/// A zargunaught argument parser, with global options and commands.
pub const ArgParser = struct {
    name: []const u8,
    parserOpts: ArgParserOpts,
    options: OptionList,

    groupData: std.StringHashMap(*GroupData),
    // Contains all commands, even grouped ones.
    commands: CommandList,
    alloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, opts: ArgParserOpts) !ArgParser {
        var argsParser = ArgParser{ .name = "", .parserOpts = opts, .options = OptionList.init(allocator), .commands = CommandList.init(allocator), .groupData = std.StringHashMap(*GroupData).init(allocator), .alloc = allocator };

        if (opts.name != null) {
            argsParser.name = opts.name.?;
        }

        if (opts.opts != null) {
            try argsParser.options.addOptions(opts.opts.?);
        }

        if (opts.commands != null) {
            for (opts.commands.?) |cmd| {
                var cmdItem: Command = .{ .name = cmd.name, .description = cmd.description, .group = cmd.group, .options = OptionList.init(allocator) };

                if (cmd.opts != null) {
                    try cmdItem.options.addOptions(cmd.opts.?);
                }

                try argsParser.commands.data.append(cmdItem);
            }
        }

        if (opts.groups != null) {
            const groups = opts.groups.?;
            for (groups) |group| {
                // Add the description to our group meta data map.
                if (group.description != null) {
                    const newGroupData = try allocator.create(GroupData);
                    newGroupData.* = .{ .description = group.description };
                    try argsParser.groupData.put(group.name, newGroupData);
                }

                for (group.commands) |cmd| {
                    var cmdItem: Command = .{ .name = cmd.name, .description = cmd.description, .group = group.name, .options = OptionList.init(allocator) };

                    if (cmd.opts != null) {
                        try cmdItem.options.addOptions(cmd.opts.?);
                    }

                    try argsParser.commands.data.append(cmdItem);
                }
            }
        }

        return argsParser;
    }

    pub fn deinit(self: *ArgParser) void {
        self.options.deinit();
        self.commands.deinit();

        // TODO: Free up group meta data.
        self.groupData.deinit();
    }

    fn updateOptionResultForOption(parseResult: *ArgParserResult, opt: *const Option) !*OptionResult {
        const existing = parseResult.option(opt.longName);
        var optResult = blk: {
            if (existing) |existingOptResult| {
                break :blk existingOptResult;
            } else {
                const ores = OptionResult.init(opt.longName);
                try parseResult.options.append(ores);
                break :blk parseResult.option(opt.longName).?;
            }
        };

        optResult.numOccurences += 1;

        if (opt.maxOccurences != null) {
            if (optResult.numOccurences > opt.maxOccurences.?) {
                return error.TooManyOptionOccurences;
            }
        }

        return optResult;
    }

    fn parseOption(parseText: *ArgQueue, parseResult: *ArgParserResult, availableOpts: *const OptionList, unsetOptions: *std.ArrayList([]const u8)) !void {
        if (parseText.len == 0) return;

        const optFullName = parseText.first.?.data;

        if (std.mem.eql(u8, optFullName, "-") or
            std.mem.eql(u8, optFullName, "--"))
        {
            _ = parseText.popFirst();
            parseResult.currItemPos += 1;
            return;
        }

        var optName: []const u8 = undefined;
        var opt: ?Option = null;
        var optResult: *OptionResult = undefined;

        if (optFullName[0] == '-' and optFullName[1] == '-') {
            optName = optFullName[2..];

            // Check if we are unsetting an option.
            if (std.mem.startsWith(u8, optName, "no-")) {
                // Skip of the 'no-'
                optName = optName[3..];
                if (availableOpts.findLongOption(optName) == null) {
                    return ParseError.UnknownOption;
                }

                _ = parseText.popFirst();
                parseResult.currItemPos += 1;
                try unsetOptions.append(optName);
                return;
            } else {
                opt = availableOpts.findLongOption(optName);
                optResult = try updateOptionResultForOption(parseResult, &opt.?);
            }
        }
        // Handle single (or stacked) short option(s)
        else if (optFullName[0] == '-') {
            optName = optFullName[1..];
            while (optName.len > 0) {
                const optFindResult = availableOpts.findShortOption(optName);
                opt = optFindResult.opt;
                if (optFindResult.opt == null) break;

                // Create option result and update number of occurences.
                optResult = try updateOptionResultForOption(parseResult, &opt.?);
                optName = optFindResult.remaining;
            }
        }

        _ = parseText.popFirst();
        parseResult.currItemPos += 1;

        // Handle parameters for the option result (last one in a stacked short option case)
        if (opt != null) {
            var paramCounter: usize = 0;
            while (parseText.len > 0 and
                (opt.?.maxNumParams == null or
                // TODO: Fix maxNumParams == 0 case for min params.
                paramCounter < opt.?.maxNumParams.?)) : (paramCounter += 1)
            {
                const currVal = parseText.first.?.data;
                if (currVal[0] == '-' and currVal.len > 1) {
                    if (!std.ascii.isDigit(currVal[1])) break;
                }

                optResult.values.append(currVal) catch return;
                _ = parseText.popFirst();
                parseResult.currItemPos += 1;
            }

            // TODO: must be done at end of parsing once multiple options have been handled.
            if (opt.?.minNumParams != null and optResult.values.items.len < opt.?.minNumParams.?) {
                return ParseError.TooFewOptionParams;
            }
        } else {
            return ParseError.UnknownOption;
        }

        return;
    }

    fn isNextItemLikelyAnOption(queue: *const ArgQueue) bool {
        return queue.len > 0 and
            queue.first != null and
            queue.first.?.data.len > 0 and
            queue.first.?.data[0] == '-';
    }

    pub fn parse(self: *ArgParser) !ArgParserResult {
        var arr = std.ArrayList([]const u8).init(self.alloc);
        defer arr.deinit();

        var args = try std.process.argsWithAllocator(self.alloc);
        _ = args.next(); // Skip the program name.
        defer args.deinit();
        while (true) {
            const curr = args.next();
            if (curr == null) break;

            const argSlice = utils.cStrToSlice(curr.?);
            try arr.append(argSlice);
        }

        return self.parseArray(arr.items);
    }

    // TODO: Add in returning state for case where we hit `-`
    pub fn parseArgsForOptions(parseResult: *ArgParserResult, availableOpts: *const OptionList, parseText: *ArgQueue, unsetOptions: *std.ArrayList([]const u8)) !void {
        while (isNextItemLikelyAnOption(parseText)) {
            // Check if we ran into a number
            const frontData = parseText.first.?.data;
            if (frontData.len > 1 and std.ascii.isDigit(frontData[1])) break;

            // TODO: change to catching and adding a better error.
            try parseOption(parseText, parseResult, availableOpts, unsetOptions);
        }
    }

    // Parses the array of string slices.
    pub fn parseArray(self: *ArgParser, args: [][]const u8) !ArgParserResult {
        // for (self.options.options.items) |opt| {
        //     std.debug.print("Option: --{s}, -{s}\n", .{ opt.longName, opt.shortName });
        // }

        var parseText = ArgQueue{};
        for (args) |arg| {
            const new_node = self.alloc.create(ArgQueue.Node) catch unreachable;
            new_node.* = ArgQueue.Node{ .prev = undefined, .next = undefined, .data = arg };
            parseText.append(new_node);
        }

        var parseResult = ArgParserResult.init(self.alloc);
        // var lastOpt: ?OptionResult = null;

        // Create a temporary option list to use to find combined global and command level options.
        // Allso used for handling checking for adding in default values at the end.
        var availableOpts = OptionList.init(self.alloc);
        defer availableOpts.deinit();

        try availableOpts.addOptions(self.options.data.items);

        // if(parseText.len == 0) return parseResult;

        var unsetOptions = std.ArrayList([]const u8).init(self.alloc);
        defer unsetOptions.deinit();

        if (parseText.len > 0) {
            try parseArgsForOptions(&parseResult, &self.options, &parseText, &unsetOptions);
        }

        if (parseText.len > 0) {
            // Setup command list.
            const frontData = parseText.first.?.data;

            // Handle looking for commands after any initial global options.
            for (0..self.commands.data.items.len) |cmdIdx| {
                const cmd: *Command = &self.commands.data.items[cmdIdx];
                if (std.mem.eql(u8, cmd.name, frontData)) {
                    parseResult.command = cmd;

                    _ = parseText.popFirst();

                    // Add the command level options to our temp opts list.
                    try availableOpts.addOptions(cmd.options.data.items);

                    try parseArgsForOptions(&parseResult, &availableOpts, &parseText, &unsetOptions);
                }
            }
        }

        // Handle filling in any options with defaults that weren't specified but have defaults configured.
        defaultOptLoop: for (availableOpts.data.items) |opt| {
            if (opt.default == null) continue;

            if (!parseResult.hasOption(opt.longName)) {

                // Check if we specifically unset an option.
                for (unsetOptions.items) |unset| {
                    if (std.mem.eql(u8, opt.longName, unset)) {
                        continue :defaultOptLoop;
                    }
                }

                const defaultVal = opt.default.?;
                var optResult = OptionResult.init(opt.longName);
                switch (defaultVal) {
                    ._params => |p| {
                        for (p.values) |pi| {
                            try optResult.values.append(pi);
                        }
                        try parseResult.options.append(optResult);
                    },
                    ._param => |p| {
                        try optResult.values.append(p.value);
                        try parseResult.options.append(optResult);
                    },
                    ._set => |s| {
                        // You could specify a default of not set, so handle
                        // that case too.
                        if (s.on) {
                            try parseResult.options.append(optResult);
                        }
                    },
                }
            }
        }

        // The rest of the arguments are positional.
        while (parseText.len > 0) {
            const posData = parseText.first.?.data;
            try parseResult.positional.append(posData);
            _ = parseText.popFirst();
        }

        // Check for too feww or too many positional arguments.
        if (self.parserOpts.minNumPositionalArgs != null) {
            const minPosArgs = self.parserOpts.minNumPositionalArgs.?;
            if (parseResult.positional.items.len < minPosArgs) {
                return ParseError.TooFewPositionalArguments;
            }
        }

        if (self.parserOpts.maxNumPositionalArgs != null) {
            const maxPosArgs = self.parserOpts.maxNumPositionalArgs.?;
            if (parseResult.positional.items.len > maxPosArgs) {
                return ParseError.TooManyPositionalArguments;
            }
        }

        return parseResult;
    }
};

pub const ArgParserResult = struct {
    // optionsList: OptionList, // Subparser options
    currItemPos: usize,
    options: std.ArrayList(OptionResult),
    command: ?*Command,
    positional: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) ArgParserResult {
        return .{ .currItemPos = 0, .options = std.ArrayList(OptionResult).init(allocator), .command = null, .positional = std.ArrayList([]const u8).init(allocator) };
    }

    pub fn deinit(self: *ArgParserResult) void {
        self.options.deinit();
        self.positional.deinit();
    }

    pub fn hasOption(self: *ArgParserResult, name: []const u8) bool {
        for (self.options.items) |o| {
            if (std.mem.eql(u8, o.name, name)) return true;
        }

        return false;
    }

    pub fn option(self: *const ArgParserResult, optName: []const u8) ?*OptionResult {
        for (0..self.options.items.len) |idx| {
            const o = &self.options.items[idx];
            if (std.mem.eql(u8, o.name, optName)) {
                return o;
            }
        }

        return null;
    }

    // Get the first value if it exists.
    pub fn optionVal(self: *const ArgParserResult, optName: []const u8) ?[]const u8 {
        if (self.option(optName)) |o| {
            if (o.values.items.len > 0) {
                return o.values.items[0];
            }
        }

        return null;
    }

    pub fn optionValOrDefault(self: *const ArgParserResult, optName: []const u8, default: []const u8) []const u8 {
        if (self.option(optName)) |o| {
            if (o.values.items.len > 0) {
                return o.values.items[0];
            }
        }

        return default;
    }

    pub fn optionNumVal(self: *const ArgParserResult, comptime T: type, optName: []const u8) !T {
        const optVal = self.optionVal(optName);
        if (optVal == null) return error.UnknownOption;

        switch (T) {
            u8, u16, u32, u64 => {
                return try std.fmt.parseUnsigned(T, optVal.?, 0);
            },
            i8, i16, i32, i64 => {
                return try std.fmt.parseInt(T, optVal.?, 0);
            },
            f32, f64 => {
                return try std.fmt.parseFloat(T, optVal.?);
            },
            else => {
                return error.UnhandledOptionType;
            },
        }
    }

    pub fn optionNumValOrDefault(self: *ArgParserResult, comptime T: type, optName: []const u8, default: T) !T {
        const optVal = self.optionVal(optName);
        if (optVal == null) return default;

        switch (T) {
            u8, u16, u32, u64 => {
                return try std.fmt.parseUnsigned(T, optVal.?, 0);
            },
            i8, i16, i32, i64 => {
                return try std.fmt.parseInt(T, optVal.?, 0);
            },
            f32, f64 => {
                return try std.fmt.parseFloat(T, optVal.?);
            },
            else => {
                return error.UnhandledOptionType;
            },
        }
    }
};
