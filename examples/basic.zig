// zig fmt: off
const std = @import("std");
const zargs = @import("zargunaught");

const Option = zargs.Option;

pub fn main() !void {
    try basicOptionParsing();
}

fn basicOptionParsing() !void {
    // std.debug.print("Basic option parsing...\n", .{});
    var parser = try zargs.ArgParser.init(
        std.heap.page_allocator, .{ 
            .name = "Test program",
            .description = "A cool test program",
            .usage = "Mostly used to transmogrify a thing into a thing.",
            .opts = &.{
                .{ .longName = "alpha", .shortName = "a", .description = "The first option", .maxNumParams = 0 },
                .{ .longName = "beta", .shortName = "b", .description = "Another option", .maxNumParams = 1 },
                .{ .longName = "gamma", .shortName = "g", .description = "The last option here."},
                .{ .longName = "help", .shortName="h", .description = "Prints out help for the program." },
            },
            .commands = &.{
            .{ .name = "transmogrify", 
               .opts = &.{
                    .{ .longName = "into", .shortName = "i", .description = "What you want to transform into. This is super useful if you want to change what you look like or pretend to be someone else for a prank.  Highly recommended!", .maxNumParams = 1 }
                }
            }
        }
    });
    defer parser.deinit();

    var args = parser.parse() catch |err| {
        std.debug.print("Error parsing args: {any}\n", .{err});
        return;
    };
    defer args.deinit();

    var stdout = try zargs.print.Printer.stdout(std.heap.page_allocator);
    defer stdout.deinit();

    if(args.hasOption("help")) {
        var help = zargs.help.HelpFormatter.init(&parser, stdout, zargs.help.DefaultTheme);
        help.printHelpText() catch |err| {
            std.debug.print("Err: {any}\n", .{err});
        };
    }
    else if(args.command != null) {
        if(std.mem.eql(u8, args.command.?.name, "transmogrify")) {
            if(args.optionVal("into")) |into| {
                try stdout.print("Turning you into {s}!!\n", .{into});
            }
            else {
                try stdout.print("Transmogrifying into something indeterminate!\n", .{});
            }
        }
    }

    for (args.options.items) |opt| {
        try stdout.print("Got option: {s}\n", .{opt.name});
        for (opt.values.items) |val| {
            try stdout.print("  - {s}\n", .{val});
        }
    }

    try stdout.flush();
}
