const std = @import("std");
const testing = std.testing;

const parser = @import("./parser.zig");
const Parser = parser.Parser;
const ValueKind = parser.ValueKind;

test "Parser.addArg stores dest, name, help, and inferred kinds" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    var count: i64 = 0;
    var ratio: f64 = 0;
    try p.addArg(&input, .{ .name = "input", .help = "File to process" });
    try p.addArg(&count, .{ .name = "count" });
    try p.addArg(&ratio, .{ .name = "ratio", .help = "Scale factor" });

    try testing.expectEqual(3, p.args.items.len);

    try testing.expectEqual(ValueKind.string, p.args.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.args.items[0].dest), @intFromPtr(&input));
    try testing.expectEqualStrings("input", p.args.items[0].name);
    try testing.expectEqualStrings("File to process", p.args.items[0].help);

    try testing.expectEqual(ValueKind.integer, p.args.items[1].kind);
    try testing.expectEqual(@intFromPtr(p.args.items[1].dest), @intFromPtr(&count));
    try testing.expectEqualStrings("count", p.args.items[1].name);
    try testing.expectEqualStrings("", p.args.items[1].help);

    try testing.expectEqual(ValueKind.float, p.args.items[2].kind);
    try testing.expectEqual(@intFromPtr(p.args.items[2].dest), @intFromPtr(&ratio));
    try testing.expectEqualStrings("ratio", p.args.items[2].name);
    try testing.expectEqualStrings("Scale factor", p.args.items[2].help);
}

test "Parser.addArg writes through a struct field pointer" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var config = struct { input: []const u8 }{ .input = "" };
    try p.addArg(&config.input, .{ .name = "input", .help = "File to process" });

    try testing.expectEqual(1, p.args.items.len);
    try testing.expectEqual(ValueKind.string, p.args.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.args.items[0].dest), @intFromPtr(&config.input));
    try testing.expectEqualStrings("input", p.args.items[0].name);
    try testing.expectEqualStrings("File to process", p.args.items[0].help);
}

test "Parser.addFlag adds a flag to the parser" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var verbose = false;
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose" });
    try testing.expectEqual(1, p.flags.items.len);
    try testing.expectEqual(ValueKind.boolean, p.flags.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[0].dest.?), @intFromPtr(&verbose));
    try testing.expectEqual('v', p.flags.items[0].short.?);
    try testing.expectEqualStrings("verbose", p.flags.items[0].long.?);
    try testing.expectEqualStrings("", p.flags.items[0].help);
}

test "Parser.addFlag adds a flag to the parser with a short name" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var verbose = false;
    try p.addFlag(&verbose, .{ .short = 'v', .help = "Verbose output" });
    try testing.expectEqual(1, p.flags.items.len);
    try testing.expectEqual(ValueKind.boolean, p.flags.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[0].dest.?), @intFromPtr(&verbose));
    try testing.expectEqual('v', p.flags.items[0].short.?);
    try testing.expectEqual(null, p.flags.items[0].long);
    try testing.expectEqualStrings("Verbose output", p.flags.items[0].help);
}

test "Parser.addFlag adds a flag to the parser with a long name" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var verbose = false;
    try p.addFlag(&verbose, .{ .long = "verbose", .help = "Verbose output" });
    try testing.expectEqual(1, p.flags.items.len);
    try testing.expectEqual(ValueKind.boolean, p.flags.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[0].dest.?), @intFromPtr(&verbose));
    try testing.expectEqual(null, p.flags.items[0].short);
    try testing.expectEqualStrings("verbose", p.flags.items[0].long.?);
    try testing.expectEqualStrings("Verbose output", p.flags.items[0].help);
}

test "Parser.addFlag adds a flag to the parser with a help text" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var verbose = false;
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose", .help = "Verbose output" });
    try testing.expectEqual(1, p.flags.items.len);
    try testing.expectEqual(ValueKind.boolean, p.flags.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[0].dest.?), @intFromPtr(&verbose));
    try testing.expectEqual('v', p.flags.items[0].short.?);
    try testing.expectEqualStrings("verbose", p.flags.items[0].long.?);
    try testing.expectEqualStrings("Verbose output", p.flags.items[0].help);
}

test "Parser.addFlag infers integer, float, and string kinds" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var count: i64 = 0;
    var ratio: f64 = 0;
    var name: []const u8 = "";
    try p.addFlag(&count, .{ .short = 'c', .long = "count" });
    try p.addFlag(&ratio, .{ .short = 'r', .long = "ratio" });
    try p.addFlag(&name, .{ .short = 'n', .long = "name" });

    try testing.expectEqual(ValueKind.integer, p.flags.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[0].dest.?), @intFromPtr(&count));
    try testing.expectEqual(ValueKind.float, p.flags.items[1].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[1].dest.?), @intFromPtr(&ratio));
    try testing.expectEqual(ValueKind.string, p.flags.items[2].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[2].dest.?), @intFromPtr(&name));
}

test "Parser.addFlag writes through a struct field pointer" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var config = struct { show_help: bool }{ .show_help = false };
    try p.addFlag(&config.show_help, .{ .short = 'h', .long = "help", .help = "Show this help" });

    try testing.expectEqual(ValueKind.boolean, p.flags.items[0].kind);
    try testing.expectEqual(@intFromPtr(p.flags.items[0].dest.?), @intFromPtr(&config.show_help));
    try testing.expectEqual('h', p.flags.items[0].short.?);
    try testing.expectEqualStrings("help", p.flags.items[0].long.?);
    try testing.expectEqualStrings("Show this help", p.flags.items[0].help);
}

test "Parser.parse parses positional arguments" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    var count: i64 = 0;
    var ratio: f64 = 0;
    try p.addArg(&input, .{ .name = "input", .help = "File to process" });
    try p.addArg(&count, .{ .name = "count" });
    try p.addArg(&ratio, .{ .name = "ratio", .help = "Scale factor" });

    try p.parse(&.{ "file.txt", "3", "1.5" });
    try testing.expectEqualStrings("file.txt", input);
    try testing.expectEqual(@as(i64, 3), count);
    try testing.expectEqual(1.5, ratio);
}

test "Parser.parse parses flags" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var verbose = false;
    var count: i64 = 0;
    var ratio: f64 = 0;
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose" });
    try p.addFlag(&count, .{ .short = 'c', .long = "count" });
    try p.addFlag(&ratio, .{ .short = 'r', .long = "ratio", .help = "Scale factor" });

    try p.parse(&.{ "-v", "-c", "3", "--ratio=1.5" });
    try testing.expect(verbose);
    try testing.expectEqual(@as(i64, 3), count);
    try testing.expectEqual(1.5, ratio);
}

test "Parser.parse returns an error if an unknown argument is provided" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    try testing.expectError(error.UnknownArgument, p.parse(&.{"input"}));
}

test "Parser.parse returns an error if an unknown flag is provided" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();
    try testing.expectError(error.UnknownFlag, p.parse(&.{"-x"}));
}

test "Parser.parse returns an error if a flag is provided without a value" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var count: i64 = 0;
    try p.addFlag(&count, .{ .short = 'c', .long = "count" });
    try testing.expectError(error.MissingValue, p.parse(&.{"-c"}));
    try testing.expectEqualStrings("-c", p.missing.?);
    try testing.expectError(error.MissingValue, p.parse(&.{"--count"}));
    try testing.expectEqualStrings("--count", p.missing.?);
}

test "Parser.parse returns an error if a positional argument is provided without a value" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    var count: i64 = 0;
    try p.addArg(&input, .{ .name = "input", .help = "File to process" });
    try p.addArg(&count, .{ .name = "count" });

    const no_args: []const [:0]const u8 = &.{};
    try testing.expectError(error.MissingValue, p.parse(no_args));
    try testing.expectEqualStrings("input", p.missing.?);
    try testing.expectError(error.MissingValue, p.parse(&.{"file.txt"}));
    try testing.expectEqualStrings("count", p.missing.?);
}

test "Parser.addHelp stores names, help, and is_help" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    try p.addHelp(.{});
    try testing.expectEqual(1, p.flags.items.len);
    try testing.expectEqual(ValueKind.boolean, p.flags.items[0].kind);
    try testing.expectEqual(null, p.flags.items[0].dest);
    try testing.expectEqual('h', p.flags.items[0].short.?);
    try testing.expectEqualStrings("help", p.flags.items[0].long.?);
    try testing.expectEqualStrings("Show this help", p.flags.items[0].help);
    try testing.expect(p.flags.items[0].is_help);
}

test "Parser.parse sets show_help and skips remaining positionals" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    try p.addArg(&input, .{ .name = "input", .help = "File to process" });
    try p.addHelp(.{ .help = "Show this help" });

    try p.parse(&.{"--help"});
    try testing.expect(p.show_help);
    try testing.expectEqualStrings("", input);

    p.show_help = false;
    try p.parse(&.{"-h"});
    try testing.expect(p.show_help);
}

test "Parser.parse returns UnknownFlag for --help without addHelp" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    try testing.expectError(error.UnknownFlag, p.parse(&.{"--help"}));
    try testing.expect(!p.show_help);
}

test "Parser.writeUsage includes program, metavars, and help strings" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    var count: i64 = 0;
    var verbose = false;
    try p.addArg(&input, .{ .name = "input", .help = "File to process" });
    try p.addArg(&count, .{ .name = "count" });
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose", .help = "Print verbose output" });
    try p.addHelp(.{ .help = "Show this help" });

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog [options] <input> <count>
        \\
        \\Arguments:
        \\  input    File to process
        \\  count
        \\
        \\Options:
        \\  -v, --verbose    Print verbose output
        \\  -h, --help       Show this help
        \\
    , aw.written());
}

test "Parser.init stores parser options" {
    var p = Parser.init(testing.allocator, "yaap", .{
        .description = "short",
        .long_description = "long",
        .usage = "custom",
        .examples = &.{ "yaap file", "yaap -v file" },
    });
    defer p.deinit();

    try testing.expectEqualStrings("yaap", p.program);
    try testing.expectEqualStrings("short", p.options.description.?);
    try testing.expectEqualStrings("long", p.options.long_description.?);
    try testing.expectEqualStrings("custom", p.options.usage.?);
    try testing.expectEqual(2, p.options.examples.?.len);
}

test "Parser.parse parses mixed flags and positionals" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    var verbose = false;
    var count: i64 = 0;
    try p.addArg(&input, .{ .name = "input" });
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose" });
    try p.addFlag(&count, .{ .short = 'c', .long = "count" });

    try p.parse(&.{ "-v", "file.txt", "--count", "4" });
    try testing.expect(verbose);
    try testing.expectEqualStrings("file.txt", input);
    try testing.expectEqual(@as(i64, 4), count);
}

test "Parser.parse skips empty tokens" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    try p.addArg(&input, .{ .name = "input" });

    try p.parse(&.{ "", "file.txt", "" });
    try testing.expectEqualStrings("file.txt", input);
}

test "Parser.parse treats a single dash as a positional" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    try p.addArg(&input, .{ .name = "input" });

    try p.parse(&.{"-"});
    try testing.expectEqualStrings("-", input);
}

test "Parser.parse returns InvalidValue for non-numeric flag and arg values" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var count: i64 = 0;
    var ratio: f64 = 0;
    try p.addFlag(&count, .{ .short = 'c', .long = "count" });
    try p.addArg(&ratio, .{ .name = "ratio" });

    try testing.expectError(error.InvalidValue, p.parse(&.{ "-c", "nope" }));
    try testing.expectError(error.InvalidValue, p.parse(&.{"nope"}));
}

test "Parser.parse returns MissingValue for an empty attached flag value" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var name: []const u8 = "";
    try p.addFlag(&name, .{ .short = 'n', .long = "name" });

    try testing.expectError(error.MissingValue, p.parse(&.{"--name="}));
    try testing.expectEqualStrings("--name", p.missing.?);

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeError(&aw.writer, error.MissingValue);
    try testing.expectEqualStrings("missing value for --name\n", aw.written());
}

test "Parser.parse stops after help and ignores remaining tokens" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    try p.addArg(&input, .{ .name = "input" });
    try p.addHelp(.{});

    try p.parse(&.{ "--help", "-x", "file.txt" });
    try testing.expect(p.show_help);
    try testing.expectEqualStrings("", input);
}

test "Parser.writeUsage omits options and arguments sections when empty" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings("Usage: prog\n", aw.written());
}

test "Parser.writeUsage includes description, custom usage, and examples" {
    var p = Parser.init(testing.allocator, "prog", .{
        .description = "Short blurb.",
        .long_description = "A longer explanation.",
        .usage = "Usage: prog [--verbose] FILE",
        .examples = &.{ "prog file.txt", "prog -v file.txt" },
    });
    defer p.deinit();

    var verbose = false;
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose", .help = "Print verbose output" });

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Short blurb.
        \\
        \\A longer explanation.
        \\
        \\Usage: prog [--verbose] FILE
        \\
        \\Examples:
        \\  prog file.txt
        \\  prog -v file.txt
        \\
        \\Options:
        \\  -v, --verbose    Print verbose output
        \\
    , aw.written());
}

test "Parser.writeUsage omits [options] when there are no flags" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var input: []const u8 = "";
    try p.addArg(&input, .{ .name = "input", .help = "File to process" });

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog <input>
        \\
        \\Arguments:
        \\  input    File to process
        \\
    , aw.written());
}

test "Parser.addCommand stores name, help, and parser pointer" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addCommand(&build, .{ .name = "build", .help = "Build the project" });
    try testing.expectEqual(1, p.commands.items.len);
    try testing.expectEqualStrings("build", p.commands.items[0].name);
    try testing.expectEqualStrings("Build the project", p.commands.items[0].help);
    try testing.expectEqual(&build, p.commands.items[0].parser);
    try testing.expectEqual(&p, build.parent.?);
    try testing.expectEqualStrings("build", build.command_name);
}

test "Parser.addCommand conflicts with positional arguments" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    var input: []const u8 = "";
    try p.addArg(&input, .{ .name = "input" });
    try testing.expectError(error.CommandsConflictWithArgs, p.addCommand(&build, .{ .name = "build" }));
}

test "Parser.addArg conflicts with subcommands" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    var input: []const u8 = "";
    try p.addCommand(&build, .{ .name = "build" });
    try testing.expectError(error.CommandsConflictWithArgs, p.addArg(&input, .{ .name = "input" }));
}

test "Parser.parse dispatches to a subcommand after parent flags" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    var verbose = false;
    var release = false;
    try p.addFlag(&verbose, .{ .short = 'v', .long = "verbose" });
    try build.addFlag(&release, .{ .short = 'r', .long = "release" });
    try p.addCommand(&build, .{ .name = "build", .help = "Build the project" });

    try p.parse(&.{ "-v", "build", "--release" });
    try testing.expect(verbose);
    try testing.expect(release);
    try testing.expectEqualStrings("build", p.command.?);
    try testing.expectEqual(&build, p.selected.?);
}

test "Parser.parse returns MissingValue when a command is required" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addCommand(&build, .{ .name = "build" });
    try testing.expectError(error.MissingValue, p.parse(&.{}));
    try testing.expectEqualStrings("command", p.missing.?);
}

test "Parser.parse returns UnknownCommand for an unregistered command" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addCommand(&build, .{ .name = "build" });
    try testing.expectError(error.UnknownCommand, p.parse(&.{"test"}));
}

test "Parser.parse parent help does not require a command" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addHelp(.{});
    try p.addCommand(&build, .{ .name = "build" });

    try p.parse(&.{"--help"});
    try testing.expect(p.show_help);
    try testing.expectEqual(null, p.command);
    try testing.expect(p.helpRequested());
    try testing.expect(p.helpTarget() == &p);
}

test "Parser.parse child help sets the child show_help" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try build.addHelp(.{});
    try p.addCommand(&build, .{ .name = "build" });

    try p.parse(&.{ "build", "--help" });
    try testing.expectEqualStrings("build", p.command.?);
    try testing.expectEqual(&build, p.selected.?);
    try testing.expect(build.show_help);
    try testing.expect(!p.show_help);
    try testing.expect(p.helpRequested());
    try testing.expect(p.helpTarget() == &build);
}

test "Parser.parse copies child missing onto the parent" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    var count: i64 = 0;
    try build.addFlag(&count, .{ .short = 'c', .long = "count" });
    try p.addCommand(&build, .{ .name = "build" });

    try testing.expectError(error.MissingValue, p.parse(&.{ "build", "-c" }));
    try testing.expectEqualStrings("-c", p.missing.?);
}

test "Parser.writeUsage lists commands and uses <command>" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();
    var test_cmd = Parser.initCommand(testing.allocator, .{});
    defer test_cmd.deinit();

    try p.addCommand(&build, .{ .name = "build", .help = "Build the project" });
    try p.addCommand(&test_cmd, .{ .name = "test", .help = "Run tests" });
    try p.addHelp(.{ .help = "Show this help" });

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog [options] <command>
        \\
        \\Commands:
        \\  build    Build the project
        \\  test     Run tests
        \\
        \\Options:
        \\  -h, --help    Show this help
        \\
    , aw.written());
}

test "Parser.writeUsage on root after parent --help prints parent usage" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addHelp(.{});
    try p.addCommand(&build, .{ .name = "build", .help = "Build the project" });

    try p.parse(&.{"--help"});

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog [options] <command>
        \\
        \\Commands:
        \\  build    Build the project
        \\
        \\Options:
        \\  -h, --help    Show this help
        \\
    , aw.written());
}

test "Parser.writeUsage on root after child --help prints child usage" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addHelp(.{});
    try build.addHelp(.{});
    try p.addCommand(&build, .{ .name = "build", .help = "Build the project" });

    try p.parse(&.{ "build", "--help" });

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog build [options]
        \\
        \\Options:
        \\  -h, --help    Show this help
        \\
    , aw.written());
}

test "Parser.writeUsage on root after a selected command without help prints parent usage" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    try p.addHelp(.{});
    try build.addHelp(.{});
    try p.addCommand(&build, .{ .name = "build", .help = "Build the project" });

    try p.parse(&.{"build"});
    try testing.expectEqual(&build, p.selected.?);
    try testing.expect(!p.helpRequested());

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog [options] <command>
        \\
        \\Commands:
        \\  build    Build the project
        \\
        \\Options:
        \\  -h, --help    Show this help
        \\
    , aw.written());
}

test "Parser.writeUsage reconstructs nested command program paths" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var build = Parser.initCommand(testing.allocator, .{});
    defer build.deinit();

    var pkg = Parser.initCommand(testing.allocator, .{});
    defer pkg.deinit();

    try pkg.addHelp(.{});
    try build.addCommand(&pkg, .{ .name = "pkg" });
    try p.addCommand(&build, .{ .name = "build" });

    try p.parse(&.{ "build", "pkg", "--help" });
    try testing.expect(p.helpRequested());
    try testing.expect(p.helpTarget() == &pkg);

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try p.writeUsage(&aw.writer);

    try testing.expectEqualStrings(
        \\Usage: prog build pkg [options]
        \\
        \\Options:
        \\  -h, --help    Show this help
        \\
    , aw.written());
}

test "Parser.writeError covers parse errors" {
    var p = Parser.init(testing.allocator, "prog", .{});
    defer p.deinit();

    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try p.writeError(&aw.writer, error.UnknownArgument);
    try p.writeError(&aw.writer, error.UnknownFlag);
    try p.writeError(&aw.writer, error.UnknownCommand);
    try p.writeError(&aw.writer, error.InvalidValue);
    try p.writeError(&aw.writer, error.MissingValue);
    try testing.expectEqualStrings(
        \\unknown argument
        \\unknown flag
        \\unknown command
        \\invalid value
        \\missing value
        \\
    , aw.written());
}
