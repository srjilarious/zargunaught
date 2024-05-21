// zig fmt: off
const std = @import("std");
const zargs = @import("zargunaught");

const Option = zargs.Option;

pub fn main() !void {
    try basicOptionParsing();
}

fn basicOptionParsing() !void {
    std.debug.print("Basic option parsing...\n", .{});
    var parser = try zargs.ArgParser.init(
        std.heap.page_allocator, .{ 
            .name = "Test program", 
            .description = "A cool test program", 
            .opts = &[_]Option{
                Option{ .longName = "alpha", .shortName = "a", .description = "The first option", .maxNumParams = 0 },
                Option{ .longName = "beta", .shortName = "b", .description = "Another option", .maxNumParams = 1 },
                Option{ .longName = "gamma", .shortName = "g", .description = "The last option here.", .maxNumParams = -1 },
            },
            .commands = &.{
            .{ .name = "help", .description = "Prints out this help." },
            .{ .name = "transmogrify", 
               .opts = &.{
                    .{ .longName = "into", .shortName = "i", .description = "What you want to transform into.", .maxNumParams = 1 }
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

    if(args.command != null) {
        if(std.mem.eql(u8, args.command.?.name, "help")) {
            var stdout = try zargs.print.Printer.stdout(std.heap.page_allocator);
            var help = zargs.help.HelpFormatter.init(&parser, stdout, zargs.help.DefaultTheme);
            help.printHelpText() catch |err| {
                std.debug.print("Err: {any}\n", .{err});
            };
            try stdout.flush();
        }
    }
    else {
        for (args.options.items) |opt| {
            std.debug.print("Got option: {s}\n", .{opt.name});
            for (opt.values.items) |val| {
                std.debug.print("  - {s}\n", .{val});
            }
        }
    }

    // var args = std.ArrayList([]const u8).init(std.heap.page_allocator);
    // try args.append("--alpha");
    // try args.append("--beta");
    // try args.append("test!");
    //
    // _ = try parser.parse(args);
}
