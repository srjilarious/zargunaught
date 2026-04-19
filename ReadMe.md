# Overview

![Logo](images/zargunaught.png)

![Version Badge](https://img.shields.io/badge/Version-1.2.1-brightgreen)
![Zig Version Badge](https://img.shields.io/badge/Zig%20Version-0.16.0-%23f7a41d?logo=zig)
![License](https://img.shields.io/badge/License-MIT-blue)

Zargunaught is an argument parsing library for zig, based off of my earlier `argunaught` C++ library.  It features a simple API for configuring global options, commands and command specific options.

It doesn't try to map your options into a structure or use meta programming tricks to determine the types of option values.  It instead parses them into a results structure and provides helpers for getting them, leaving the semantic meaning up to the client program.

# Features

- Global options, with long and short names.
- Min/max number of parameters and positional arguments.
- Support for commands with extended options per command.
- Options stacking, like `-vvv` to mark `v` as having occurred 3 times, with options for max allowed (or no stacking).
- Default values for options as either set to true, single parameter or multiple parameters.
- Ability to prepend `no-` to unset a default enabled option.
- Help text formatter with word-wrapping and basic color theming support.
- Grouping of commands for better formatted help text.
- `--` to stop option parsing and consider the rest of the command line as positional arguments.

# installing

the easiest way to use `zargunaught` in your zig program is to grab the latest tag:

```
zig fetch --save https://github.com/srjilarious/zargunaught
```

and then add it as a dependency in your `build.zig`:

```
const zargsmod = b.dependency("zargunaught", .{});
exe.root_module.addImport("zargunaught", zargsmod.module("zargunaught"));
```

# example

a simple configuration and parsing example can be seen in the `examples/basic.zig` program

here's what the help output looks like for the basic example below:

![basic example help output](images/basic_example_help.png)

and here's the setup code in the example:

```zig
var parser = try zargs.ArgParser.init(
    std.heap.page_allocator, 
    .{
        .name = "test program",
        .description = "a cool test program",
        .usage = "mostly used to transmogrify a thing into a thing.",
        .opts = &[_]Option{
            Option{
                .longName = "alpha",
                .shortName = "a",
                .description = "the first option",
                .maxNumParams = 0,
            },
            Option{
                .longName = "beta",
                .shortName = "b",
                .description = "another option",
                .maxNumParams = 1,
            },
            Option{
                .longName = "gamma",
                .shortName = "g",
                .description = "the last option here.",
                .maxNumParams = -1,
            },
        },
        .commands = &.{
            .{
                .name = "help",
                .description = "prints out this help.",
            },
            .{ .name = "transmogrify", .opts = &.{
                .{
                    .longName = "into",
                    .shortName = "i",
                    .description = "what you want to transform into. this is super useful if you want to change what you look like or pretend to be someone else for a prank.  highly recommended!",
                    .maxNumParams = 1,
                },
            },
        },
    },
});

defer parser.deinit();

var args = parser.parse(init.minimal.args) catch |err| {
    std.debug.print("error parsing args: {any}\n", .{err});
    return;
};
defer args.deinit();
```

here you can see global options being setup, along with commands where one has a command specific option available.


# Feature Usage

## Help text
There is a built in help formatting module that can format the information in the argument parser configuration nicely and which is easy to style with different colors and such.

it also handles wrapping lines of descriptions for options and commands that get too long and properly indenting them to be more pleasing.

to display the help text, you could use the following code:

```zig
if(args.hasOption("help")) {
    var stdout = try zargs.print.Printer.stdout(std.heap.page_allocator);
    defer stdout.deinit();

    var help = try zargs.help.HelpFormatter.init(&parser, stdout, zargs.help.DefaultTheme, std.heap.page_allocator);
    defer help.deinit();

    help.printHelpText() catch |err| {
        std.debug.print("Err: {any}\n", .{err});
    };
}
```

The `banner` field in `ArgParserOpts` lets you override the program name shown at the top of the help output.  If not set, the `name` field is used instead.

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{
    .name = "myapp",
    .banner = "My Cool App v1.0",
    .description = "Does really cool things.",
});
```

## Min/Max Parameters and Positional Arguments

By default there are no minimum or maximum number of parameters for each option, which means a user is able to provide as many, or no parameters to an option.  If you want the parser to throw an error depending on the number of parameters to an option:

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Simple options", .opts = &.{
    .{ .longName = "delta", .shortName = "d", .description = "", .minNumParams = 1, .maxNumParams = 3 },
} });
```

This would force the delta option to be provided with one to three parameters by the user.

You can similarly configure the parser to expect a minimum and/or maximum number of positional arguments.  The optional `positionalDescription` field adds a label for positional arguments in the help text:

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{
    .name = "Simple options",
    .minNumPositionalArgs = 1,
    .maxNumPositionalArgs = 2,
    .positionalDescription = "<input-file> [output-file]",
});
```

You can also provide `defaultPositionalArgs` to supply positional arguments when none are given by the user:

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{
    .name = "Simple options",
    .defaultPositionalArgs = zargs.DefaultValue.params(&.{ "default.txt" }),
});
```

## Default Values

The following shows the three options for default values

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Default options", .opts = &.{
  .{ .longName = "beta", .shortName = "b", .description = "", .default = zargs.DefaultValue.set() },
  .{ .longName = "gamma", .shortName = "g", .description = "", .default = zargs.DefaultValue.param("blah") },
  .{ .longName = "delta", .shortName = "d", .description = "", .default = zargs.DefaultValue.params(&.{ "boop", "blop", "bleep" }) },
} });
```

Here `beta` will be set, but no have any parameters associated with it.  A user could use `--no-beta` to unset it during argument parsing.

The `gamma` option will by default be set with a single `blah` parameter, and `delta` will be set with the three values `boop`, `blop` and `bleep`.


## Option Stacking

Options are allowed to be set multiple times, where each time adds any new parameters to the list or parameters already seen.  For example, an `input` option could be given as `--input one --input two --input three` and the result will show a single `input` `OptionResult` with three parameters.

Each time an option is seen, the `numOccurences` attribute of `OptionResult` is incremented.  You can limit the number of occurences with the `maxOccurences` attribute when defining an option:

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ .name = "Simple options", .opts = &.{
        .{ .longName = "verbose", .shortName = "v", .description = "log verbosity", .maxOccurences = 5 },
        .{ .longName = "delta", .shortName = "d", .description = "" },
    } });
```

## Command Groups

Command groups are useful for gathering a number of related commands together when printing out the help text.  They can be defined in the `ArgParser` initial configuration by providing a list of `GroupOpt` structs with a `name`, optional `description`, and an array of commands:

```zig
var parser = try zargs.ArgParser.init(std.heap.page_allocator, .{ 
    .name = "Simple command configuration", 
    .opts = &.{
        .{ .longName = "beta", .shortName = "b", .description = "", .maxNumParams = 1 },
        .{ .longName = "delta", .shortName = "d", .description = "", .maxNumParams = 1 },
    },
    .commands = &.{
        .{ .name = "test" },
        .{ .name = "transmogrify", .group = "experimental",
            .opts = &.{
                .{ .longName = "into", .shortName = "i", .description = "", .maxNumParams = 1 }
            }
        }
    },
    .groups = &.{
        .{
            .name = "evocation",
            .description = "Magical incantations and evocations.",
            .commands = &.{ 
                .{ .name = "fire" },
                .{ .name = "ice" },
                .{ .name = "thunder" }
            }
        }
    }
});
```

The `description` on a group is shown beneath the group name in the help output.  Commands can also be assigned to a group directly by setting the `group` field on a `CommandOpt` to the group name (as shown with `transmogrify` above); this is useful when you want to add a single command to an existing group without listing all group commands together.

## Accessing Parse Results

`ArgParserResult` provides several helpers for reading option values:

- `hasOption(name)` — returns `true` if the option was set (including via defaults)
- `option(name)` — returns a `?*OptionResult`, giving access to `values` and `numOccurences`
- `optionVal(name)` — returns `?[]const u8` for the first parameter value
- `optionValOrDefault(name, default)` — like `optionVal` but falls back to `default` if not set
- `optionNumVal(T, name)` — parses the first parameter value as a numeric type (`u8`–`u64`, `i8`–`i64`, `f32`, `f64`)
- `optionNumValOrDefault(T, name, default)` — like `optionNumVal` but returns `default` if the option is absent

```zig
// Check a flag
if (args.hasOption("verbose")) { ... }

// Read a string value
const output = args.optionValOrDefault("output", "out.txt");

// Read a numeric value
const count = try args.optionNumVal(u32, "count");
const timeout = try args.optionNumValOrDefault(f32, "timeout", 30.0);
```

Positional arguments (those not associated with any option or command) are available in `args.positional.items` as a `[][]const u8`.
