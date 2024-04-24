// zig fmt: off
const std = @import("std");

pub const ParserConfigError = error{ 
    LongOptionNameMissing,
    OptionBeginsWithNumber,
    DuplicateOption,
    CommandNameMissing,
    DuplicateCommandName,
    CommandGroupNameMissing,
};

pub const ParseError = error{UnknownOption};

pub const Option = struct {
    longName: []const u8,
    shortName: []const u8,
    description: []const u8,
    maxNumParams: i8 = 0,
};

pub const OptionResult = struct {
    name: []const u8,
    values: std.ArrayList([]const u8),

    pub fn init(name: []const u8) OptionResult {
        // TODO: fix allocator.
        return .{ .name = name, .values = std.ArrayList([]const u8).init(std.heap.page_allocator) };
    }

    pub fn deinit(self: *OptionResult) void {
        self.values.deinit();
    }
};

pub const OptionList = struct {
    options: std.ArrayList(Option),

    pub fn init(allocator: std.mem.Allocator) OptionList {
        const options = std.ArrayList(Option).init(allocator);
        return OptionList{ .options = options };
    }

    pub fn deinit(self: OptionList) void {
        self.options.deinit();
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

        for (self.options.items) |o| {
            if (std.mem.eql(u8, opt.longName, o.longName)) {
                return ParserConfigError.DuplicateOption;
            }

            if (opt.shortName.len > 0 and std.mem.eql(u8, opt.shortName, o.shortName)) {
                return ParserConfigError.DuplicateOption;
            }
        }

        self.options.append(opt) catch unreachable;
    }

    pub fn findLongOption(self: *OptionList, optName: []const u8) ?Option {
        for (self.options.items) |opt| {
            if (std.mem.eql(u8, opt.longName, optName)) {
                return opt;
            }
        }

        return null;
    }

    pub fn findShortOption(self: *OptionList, optName: []const u8) ?Option {
        for (self.options.items) |opt| {
            if (std.mem.eql(u8, opt.shortName, optName)) {
                return opt;
            }
        }

        return null;
    }
};

pub const Command = struct { 
    name: []const u8, 
    description: []const u8,
    options: OptionList 
};

pub const ArgParserOpts = struct {
    name: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    description: ?[]const u8 = null,
    usage: ?[]const u8 = null,
    opts: ?[]const Option = null,
};

pub const ArgParser = struct {
    name: []const u8,
    banner: ?[]const u8,
    description: ?[]const u8,
    usage: ?[]const u8,
    options: OptionList,
    alloc: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, opts: ArgParserOpts) !ArgParser {
        var argsParser = ArgParser{ 
            .name = "", 
            .banner = opts.banner, 
            .description = opts.description, 
            .usage = opts.usage, 
            .options = OptionList.init(allocator),
            .alloc = allocator
        };

        if(opts.name != null) {
            argsParser.name = opts.name.?;
        }

        if(opts.opts != null) {
            try argsParser.options.addOptions(opts.opts.?);
        }

        return argsParser;
    }

    pub fn deinit(self: ArgParser) void {
        self.options.deinit();
    }

    pub fn description(self: *ArgParser, desc: []const u8) *ArgParser {
        self.description = desc;
        return self;
    }

    pub fn usage(self: *ArgParser, use: []const u8) *ArgParser {
        self.usage = use;
        return self;
    }

    pub fn withOptions(self: *ArgParser, opts: []const Option) ParserConfigError!*ArgParser {
        try self.options.addOptions(opts);
        return self;
    }

    fn parseOption(self: *ArgParser, parseText: *std.TailQueue([]const u8), parseResult: *ArgParserResult) ?OptionResult {
        if (parseText.len == 0) return null;

        const optFullName = parseText.first.?.data;

        if (std.mem.eql(u8, optFullName, "-") or
            std.mem.eql(u8, optFullName, "--"))
        {
            _ = parseText.popFirst();
            parseResult.currItemPos += 1;
            return null;
        }

        var optName: []const u8 = undefined;
        var opt: ?Option = undefined;

        if (optFullName[0] == '-' and optFullName[1] == '-') {
            optName = optFullName[2..];
            // TODO Add looking for command option..
            opt = self.options.findLongOption(optName);
            std.debug.print("Found option! {s}\n", .{optName});
        }

        _ = parseText.popFirst();
        parseResult.currItemPos += 1;

        if (opt != null) {
            var optResult = OptionResult.init(opt.?.longName);

            var paramCounter: usize = 0;
            while (parseText.len > 0 and
                (opt.?.maxNumParams == -1 or
                paramCounter < opt.?.maxNumParams)) : (paramCounter += 1)
            {
                const currVal = parseText.first.?.data;
                if (currVal[0] == '-' and currVal.len > 1) {
                    if (!std.ascii.isDigit(currVal[1])) break;
                }

                optResult.values.append(currVal) catch return null;
                _ = parseText.popFirst();
                parseResult.currItemPos += 1;

                paramCounter += 1;

                std.debug.print("    Option param: {s}\n", .{currVal});
            }

            return optResult;
        } else {
            // TODO: Add unknown option error.
        }

        return null;
    }

    pub fn parse(self: *ArgParser, args: std.ArrayList([]const u8)) void {
        std.debug.print("Hello from parse!\n", .{});
        for (self.options.options.items) |opt| {
            std.debug.print("Option: --{s}, -{s}\n", .{ opt.longName, opt.shortName });
        }

        var parseText = std.TailQueue([]const u8){};
        for (args.items) |arg| {
            const new_node = self.alloc.create(std.TailQueue([]const u8).Node) catch unreachable;
            new_node.* = std.TailQueue([]const u8).Node{ .prev = undefined, .next = undefined, .data = arg };
            parseText.append(new_node);
        }

        // TODO: fix allocator usage.
        var parseResult = ArgParserResult.init(self.alloc);
        // var lastOpt: ?OptionResult = null;
        while (parseText.len > 0) {
            _ = self.parseOption(&parseText, &parseResult);
        }
    }
};

pub const ArgParserResult = struct {
    // optionsList: OptionList, // Subparser options
    currItemPos: usize,
    options: std.ArrayList(OptionResult),
    positionalArgs: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) ArgParserResult {
        return .{ 
            .currItemPos = 0, 
            .options = std.ArrayList(OptionResult).init(allocator), 
            .positionalArgs = std.ArrayList([]const u8).init(allocator) };
    }
};



