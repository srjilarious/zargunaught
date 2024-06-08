# Overview

![Zig Version](https://img.shields.io/badge/Zig%20Version-0.13.0-%23f7a41d?logo=zig)
![License](https://img.shields.io/badge/License-MIT-blue)

Zargunaught is an argument parsing library for zig, based off of my earlier `argunaught` C++ library.  It features a simple API for configuring global options, commands and command specific options.

It doesn't try to map your options into a structure or use meta programming tricks to determine the types of option values.  It instead parses them into a results structure and provides helpers for getting them, leaving the data type conversion mostly up to the client program.

# Example

A simple configuration and parsing example can be seen in the `examples/basic.zig` program:

```zig
var parser = try zargs.ArgParser.init(
    std.heap.page_allocator, .{ 
        .name = "Test program",
        .description = "A cool test program",
        .usage = "Mostly used to transmogrify a thing into a thing.",
        .opts = &[_]Option{
            Option{ .longName = "alpha", .shortName = "a", .description = "The first option", .maxNumParams = 0 },
            Option{ .longName = "beta", .shortName = "b", .description = "Another option", .maxNumParams = 1 },
            Option{ .longName = "gamma", .shortName = "g", .description = "The last option here.", .maxNumParams = -1 },
        },
        .commands = &.{
        .{ .name = "help", .description = "Prints out this help." },
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
```

Here you can see global options being setup, along with commands where one has a command specific option available.

There is a built in help formatting module that can format the information in the argument parser configuration nicely and is easy to style with different colors and such.  

It also handles wrapping lines of descriptions for options and commands that get too long and properly indenting them to be more pleasing:

```
zig build basic -- help                                                          ─╯

Test program - A cool test program

Mostly used to transmogrify a thing into a thing.

Global Options
  --alpha, -a   : The first option
  --beta, -b    : Another option
  --gamma, -g   : The last option here.

Commands
  help          : Prints out this help.

  transmogrify
    --into, -i  : What you want to transform into. This is super useful if you
                  want to change what you look like or pretend to be someone
                  else for a prank.  Highly recommended!
```

Note: Not seen here is the default ANSI coloring styles applied.
