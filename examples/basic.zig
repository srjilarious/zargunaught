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
                Option{ .longName = "alpha", .shortName = "a", .description = "", .maxNumParams = 0 },
                Option{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
                Option{ .longName = "gamma", .shortName = "g", .description = "", .maxNumParams = -1 },
            },
            .commands = &.{
            .{ .name = "help", .description = "Prints out this help." },
            .{ .name = "transmogrify", 
               .opts = &.{
                    .{ .longName = "into", .shortName = "i", .description = "", .maxNumParams = 1 }
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
            var stdout = zargs.print.Printer.debug();
            var help = zargs.help.HelpFormatter.init(&parser, stdout);
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
