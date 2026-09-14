# YAAP

Yet Another Argument Parser.

YAAP is an argument parser inspired by Python's `argparse`. While it is giving
the building blocks to make a CLI application, it is intentionally not bloated
with features like autocompletion generation, colored outputs, etc.

Instead, it gives an argument parser with an optional `--help` flag to print
the usage.

## Features

- Positional arguments
- Long and short options (e.g., `-v`, `--verbose`)
- Mixed positional arguments and options (`cmd -v arg1 --option)
- Subcommands (e.g., `cmd -v subcmd -a` )
- Clear errors on missing values
- Optional `-h | --help` option

## Installation

**1. Fetch the package**

<!-- x-release-please-start-version -->
```shell
zig fetch --save git+https://github.com/gabor-boros/yaap#v1.0.0
```
<!-- x-release-please-end -->

**2. Wire it in `build.zig`**

```zig
const yaap_dep = b.dependency("yaap", .{});
exe.root_module.addImport("yaap", yaap_dep.module("yaap"));
```

## Usage

Optional names and help text go in a spec. YAAP does not print or exit on its
own. Handling `parse` errors and help is the responsibility of the caller.

```zig
const std = @import("std");
const yaap = @import("yaap");

const Config = struct {
    input: []const u8 = "",
    verbose: bool = false,
};

pub fn main(init: std.process.Init) !void {
    var config = Config{};

    var parser = yaap.Parser.init(init.gpa, "prog", .{
        .description = "Process a file",
        .examples = &.{ "prog file.txt", "prog --help" },
    });
    defer parser.deinit();

    try parser.addHelp(.{});
    try parser.addArg(&config.input, .{ .name = "input", .help = "File to process" });

    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stderr().writer(init.io, &buf);
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    parser.parse(args[1..]) catch |err| {
        try parser.writeError(&writer.interface, err);
        try writer.interface.flush();
        return;
    };

    if (parser.helpRequested()) {
        try parser.writeUsage(&writer.interface);
        try writer.interface.flush();
        return;
    }

    std.debug.print("input file: {s}\n", .{config.input});
}
```

## Subcommands

Each subcommand is its own `Parser`. Parent flags may appear before the command
name. Remaining tokens are parsed by the child. Calling `writeUsage` on the
**root** parser prints the usage of the parser that requested help. The usage
program line is built from the parent chain, so children do not need their own
program name.

```zig
var parser = yaap.Parser.init(init.gpa, "prog", .{});
defer parser.deinit();

var build = yaap.Parser.initCommand(init.gpa, .{});
defer build.deinit();

try build.addFlag(&config.release, .{ .short = 'r', .long = "release", .help = "Optimized build" });
try build.addHelp(.{});
try parser.addCommand(&build, .{ .name = "build", .help = "Build the project" });
try parser.addHelp(.{});

parser.parse(args[1..]) catch |err| {
    try parser.writeError(writer, err);
    return;
};

if (parser.helpRequested()) {
    try parser.writeUsage(writer);
    return;
}
```

The selected child is available as `parser.selected` (and `parser.command` for
the name). Parent positionals cannot be mixed with subcommands.

## Documentation

API docs are published at [gabor-boros.github.io/yaap](https://gabor-boros.github.io/yaap/).
Generate them locally with:

```shell
zig build docs
```

Output is written to `zig-out/docs`.

## Development

Install [pre-commit](https://pre-commit.com/), then enable the hooks (requires
`zig` on `PATH`):

```shell
pre-commit install
```

CI runs the same hooks on every pull request.

## License

YAAP is licensed under the MIT license.
