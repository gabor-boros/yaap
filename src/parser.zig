const std = @import("std");
const mem = std.mem;
const testing = std.testing;

// Error returned during flag parsing.
pub const ParseError = error{
    UnknownArgument, // the provided argument is not registered
    UnknownFlag, // the provided flag is not registered
    UnknownCommand, // the provided subcommand is not registered
    MissingValue, // the argument or flag expects a value that is not provided
    InvalidValue, // the argument or flag value is invalid
};

/// The kind of a flag or positional argument value.
pub const ValueKind = enum {
    boolean,
    integer,
    float,
    string,
};

/// A positional argument filled in registration order.
pub const Arg = struct {
    /// The kind of the argument's value.
    kind: ValueKind,
    /// Pointer to the caller's destination variable.
    dest: *anyopaque,
    /// Metavar used in usage text.
    name: []const u8,
    /// Help text used when printing usage.
    help: []const u8 = "",
};

/// A nested subcommand with its own parser.
pub const Command = struct {
    /// Subcommand name matched as the first non-flag token.
    name: []const u8,
    /// Help text used when printing usage.
    help: []const u8 = "",
    /// Parser that receives the remaining arguments after the command name.
    parser: *Parser,
};

// The registered flag's specification. The short and long names are optional,
// but at least one of them must be provided. Otherwise, a compilation error is
// returned.
pub const Flag = struct {
    /// The kind of the flag's value.
    kind: ValueKind,
    /// Pointer to the caller's destination variable. Help flags have no dest.
    dest: ?*anyopaque = null,
    /// Optional short name.
    short: ?u8,
    /// Optional long name.
    long: ?[]const u8,
    /// Help text used when printing usage.
    help: []const u8 = "",
    /// When true, matching this flag stops parse and sets `Parser.show_help`.
    is_help: bool = false,
};

/// Options for the parser.
pub const ParserOptions = struct {
    /// Short description of the program to in help text.
    description: ?[]const u8 = null,
    /// Long description of the program to in help text.
    long_description: ?[]const u8 = null,
    /// Examples of the program to in help text.
    examples: ?([]const []const u8) = null,
    /// Usage of the program to in help text.
    usage: ?[]const u8 = null,
};

/// Spec for `addArg`.
pub const ArgSpec = struct {
    name: []const u8,
    help: ?[]const u8 = null,
};

/// Spec for `addFlag`. At least `short` or `long` must be set.
pub const FlagSpec = struct {
    short: ?u8 = null,
    long: ?[]const u8 = null,
    help: ?[]const u8 = null,
};

/// Spec for `addCommand`.
pub const CommandSpec = struct {
    name: []const u8,
    help: ?[]const u8 = null,
};

/// Spec for `addHelp`. Defaults to `-h` / `--help`.
pub const HelpSpec = struct {
    short: ?u8 = 'h',
    long: ?[]const u8 = "help",
    help: ?[]const u8 = null,
};

/// A positional and flag parser.
pub const Parser = struct {
    /// The allocator used to allocate the parser's internal data structures.
    allocator: mem.Allocator,
    /// Name of the program to show in usage text.
    program: []const u8,
    /// Options for the parser.
    options: ParserOptions,
    /// A list of positional arguments. Arguments are filled in registration order.
    ///
    /// `dest` must be a pointer to a mutable integer, float, or string
    /// variable. Boolean destinations are not allowed.
    ///
    /// * The `name` parameter is the metavar shown in usage text.
    /// * The `help` parameter is the help text for the argument.
    args: std.ArrayList(Arg),
    /// A list of flags. Flags are filled in registration order.
    ///
    /// `dest` must be a pointer to a mutable boolean, integer, float, or string
    /// variable. The parser writes the parsed value into that variable.
    ///
    /// * The `short` parameter is the short name of the flag.
    /// * The `long` parameter is the long name of the flag.
    /// * The `help` parameter is the help text for the flag.
    flags: std.ArrayList(Flag),
    /// Nested subcommands. The first non-flag token selects one.
    commands: std.ArrayList(Command),
    /// Name of the selected subcommand after a successful parse, or null.
    command: ?[]const u8 = null,
    /// Parser of the selected subcommand after a successful parse, or null.
    selected: ?*Parser = null,
    /// Parent parser when this parser is registered as a subcommand.
    parent: ?*Parser = null,
    /// Name of this parser in its parent, if it is a subcommand.
    command_name: []const u8 = "",
    /// Set when a registered help flag is parsed. Parse returns without
    /// requiring remaining positionals.
    show_help: bool = false,
    /// Name of the argument or flag whose value was missing when parse
    /// returned `error.MissingValue`. Flags use the form that was given
    /// (`-c`, `--count`); positionals use the metavar.
    missing: ?[]const u8 = null,

    /// Initialize the flag parser.
    pub fn init(allocator: mem.Allocator, program: []const u8, options: ParserOptions) Parser {
        return .{
            .allocator = allocator,
            .program = program,
            .options = options,
            .flags = .empty,
            .args = .empty,
            .commands = .empty,
            .command = null,
            .selected = null,
            .parent = null,
            .command_name = "",
            .show_help = false,
            .missing = null,
        };
    }

    /// Initialize a subcommand parser. The usage program line is taken from
    /// the parent chain after `addCommand`; no program name is required.
    pub fn initCommand(allocator: mem.Allocator, options: ParserOptions) Parser {
        return init(allocator, "", options);
    }

    /// Deinitialize the flag parser.
    pub fn deinit(self: *Parser) void {
        self.flags.deinit(self.allocator);
        self.args.deinit(self.allocator);
        self.commands.deinit(self.allocator);
    }

    /// Add a positional argument to the parser. Arguments are filled in
    /// registration order.
    ///
    /// `dest` must be a pointer to a mutable integer, float, or string
    /// variable. Boolean destinations are not allowed.
    ///
    /// * The `name` parameter is the metavar shown in usage text.
    /// * The `help` parameter is the help text for the argument.
    pub fn addArg(self: *Parser, dest: anytype, comptime spec: ArgSpec) !void {
        if (spec.name.len == 0) {
            @compileError("positional argument name must be set");
        }

        if (self.commands.items.len != 0) {
            return error.CommandsConflictWithArgs;
        }

        const kind = comptime valueKindFromDest(@TypeOf(dest));
        if (kind == .boolean) {
            @compileError("positional arguments cannot be boolean");
        }

        try self.args.append(self.allocator, .{
            .kind = kind,
            .dest = @ptrCast(dest),
            .name = spec.name,
            .help = spec.help orelse "",
        });
    }

    /// Parse the command line arguments.
    ///
    /// Positionals are filled in registration order. Flags that take a value
    /// read the next token, or `--name=value`. Boolean flags take no value.
    /// Missing required values return `error.MissingValue` and set `missing`
    /// to the flag or positional that still needs a value.
    ///
    /// If subcommands are registered, the first non-flag token selects one and
    /// the remainder is parsed by that command's parser. Parent flags may
    /// appear before the command name.
    ///
    /// If a help flag registered with `addHelp` is seen, `show_help` is set and
    /// parse returns without consuming the rest of the tokens or requiring
    /// remaining positionals or a command.
    pub fn parse(self: *Parser, args: []const [:0]const u8) ParseError!void {
        self.missing = null;
        self.command = null;
        self.selected = null;

        var i: usize = 0;
        var positional_index: usize = 0;

        while (i < args.len) : (i += 1) {
            const token = args[i];
            if (token.len == 0) continue;

            if (token[0] == '-' and token.len > 1) {
                try self.parseFlag(args, &i);
                if (self.show_help) return;
            } else if (self.commands.items.len > 0) {
                const cmd = self.matchCommand(token) orelse return error.UnknownCommand;
                self.command = cmd.name;
                self.selected = cmd.parser;
                cmd.parser.parse(args[i + 1 ..]) catch |err| {
                    self.missing = cmd.parser.missing;
                    return err;
                };
                return;
            } else {
                if (positional_index >= self.args.items.len) {
                    return error.UnknownArgument;
                }

                const argument = self.args.items[positional_index];
                try assignValue(argument.kind, argument.dest, token);

                positional_index += 1;
            }
        }

        if (self.commands.items.len > 0) {
            return self.failMissing("command");
        }

        if (positional_index < self.args.items.len) {
            return self.failMissing(self.args.items[positional_index].name);
        }
    }

    /// Parse a flag at `args[i]`. Advances `i` when a separate value token is consumed.
    fn parseFlag(self: *Parser, args: []const [:0]const u8, i: *usize) ParseError!void {
        const token = args[i.*];
        const flag = self.matchFlag(token) orelse return error.UnknownFlag;

        if (flag.is_help) {
            self.show_help = true;
            return;
        }

        if (flag.kind == .boolean) {
            const ptr: *bool = @ptrCast(@alignCast(flag.dest.?));
            ptr.* = true;
            return;
        }

        const value = attachedFlagValue(token) orelse blk: {
            i.* += 1;
            if (i.* >= args.len) return self.failMissing(flagDisplayName(token));
            break :blk args[i.*];
        };

        if (value.len == 0) return self.failMissing(flagDisplayName(token));

        try assignValue(flag.kind, flag.dest.?, value);
    }

    /// Add a flag to the parser. If both `short` and `long` names are missing,
    /// a compile time error is returned.
    ///
    /// `dest` must be a pointer to a mutable boolean, integer, float, or
    /// string variable. The parser writes the parsed value into that variable.
    ///
    /// * The `short` parameter is the short name of the flag.
    /// * The `long` parameter is the long name of the flag.
    /// * The `help` parameter is the help text for the flag.
    pub fn addFlag(self: *Parser, dest: anytype, comptime spec: FlagSpec) !void {
        if (spec.short == null and spec.long == null) {
            @compileError("at least a short or long name must be set");
        }

        const kind = comptime valueKindFromDest(@TypeOf(dest));

        try self.flags.append(self.allocator, .{
            .kind = kind,
            .dest = @ptrCast(dest),
            .short = spec.short,
            .long = spec.long,
            .help = spec.help orelse "",
        });
    }

    /// Register an optional help flag. When it is parsed, `show_help` is set
    /// and remaining arguments are not required.
    ///
    /// Defaults to `-h` / `--help`. If both `short` and `long` are missing, a
    /// compile time error is returned. If `help` is omitted, `"Show this help"`
    /// is used.
    pub fn addHelp(self: *Parser, comptime spec: HelpSpec) !void {
        if (spec.short == null and spec.long == null) {
            @compileError("at least a short or long name must be set");
        }

        try self.flags.append(self.allocator, .{
            .kind = .boolean,
            .short = spec.short,
            .long = spec.long,
            .help = spec.help orelse "Show this help",
            .is_help = true,
        });
    }

    /// Register a nested subcommand. The first non-flag token must match
    /// `name`; remaining arguments are parsed by `child`.
    ///
    /// Empty `name` is a compile error. Subcommands cannot be mixed with
    /// parent positional arguments.
    pub fn addCommand(self: *Parser, child: *Parser, comptime spec: CommandSpec) !void {
        if (spec.name.len == 0) {
            @compileError("subcommand name must be set");
        }

        if (self.args.items.len != 0) {
            return error.CommandsConflictWithArgs;
        }

        child.parent = self;
        child.command_name = spec.name;

        try self.commands.append(self.allocator, .{
            .name = spec.name,
            .help = spec.help orelse "",
            .parser = child,
        });
    }

    /// Write usage for the parser that requested help, or this parser if none did.
    pub fn writeUsage(self: *const Parser, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const target = if (self.helpRequested()) self.helpTarget() else self;
        try target.writeUsageAt(writer);
    }

    /// True when this parser or a selected subcommand requested help.
    pub fn helpRequested(self: *const Parser) bool {
        return self.helpTarget().show_help;
    }

    /// Parser whose usage should be shown: the one that set `show_help`,
    /// otherwise the selected leaf, otherwise self.
    pub fn helpTarget(self: *const Parser) *const Parser {
        if (self.show_help) return self;
        if (self.selected) |child| return child.helpTarget();
        return self;
    }

    fn writeProgramPath(self: *const Parser, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self.parent) |parent| {
            try parent.writeProgramPath(writer);
            try writer.print(" {s}", .{self.command_name});
        } else {
            try writer.writeAll(self.program);
        }
    }

    fn writeUsageAt(self: *const Parser, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self.options.description != null) {
            try writer.writeAll(self.options.description.?);
            try writer.writeAll("\n\n");
        }

        if (self.options.long_description != null) {
            try writer.writeAll(self.options.long_description.?);
            try writer.writeAll("\n\n");
        }

        if (self.options.usage != null) {
            try writer.writeAll(self.options.usage.?);
            try writer.writeByte('\n');
        } else {
            try writer.writeAll("Usage: ");
            try self.writeProgramPath(writer);
            if (self.flags.items.len > 0) {
                try writer.writeAll(" [options]");
            }
            if (self.commands.items.len > 0) {
                try writer.writeAll(" <command>");
            }
            for (self.args.items) |arg| {
                try writer.print(" <{s}>", .{arg.name});
            }
            try writer.writeByte('\n');
        }

        if (self.options.examples != null) {
            try writer.writeAll("\nExamples:\n");
            for (self.options.examples.?) |example| {
                try writer.print("  {s}\n", .{example});
            }
        }

        if (self.commands.items.len > 0) {
            try writer.writeAll("\nCommands:\n");
            const width = maxCommandNameLen(self.commands.items);
            for (self.commands.items) |cmd| {
                try writeAlignedHelp(writer, cmd.name, cmd.help, width);
            }
        }

        if (self.args.items.len > 0) {
            try writer.writeAll("\nArguments:\n");
            const width = maxArgNameLen(self.args.items);
            for (self.args.items) |arg| {
                try writeAlignedHelp(writer, arg.name, arg.help, width);
            }
        }

        if (self.flags.items.len > 0) {
            try writer.writeAll("\nOptions:\n");
            const width = maxFlagSpecLen(self.flags.items);
            for (self.flags.items) |flag| {
                try writeFlagHelp(writer, flag, width);
            }
        }
    }

    /// Returns the registered flag whose short form (`-x`) or long form
    /// (`--name`) matches `arg`. If no flag matches the name, `null` is
    /// returned.
    fn matchFlag(self: *const Parser, arg: []const u8) ?Flag {
        if (mem.startsWith(u8, arg, "--")) {
            const rest = arg[2..];
            if (rest.len == 0) return null;

            const name_len = mem.indexOfScalar(u8, rest, '=') orelse rest.len;
            const name = rest[0..name_len];
            if (name.len == 0) return null;

            for (self.flags.items) |item| {
                if (item.long) |long| {
                    if (mem.eql(u8, name, long)) return item;
                }
            }

            return null;
        }

        if (arg.len == 2 and arg[0] == '-') {
            for (self.flags.items) |item| {
                if (item.short) |short| {
                    if (arg[1] == short) return item;
                }
            }
        }

        return null;
    }

    /// Returns the registered subcommand whose name matches `name`.
    fn matchCommand(self: *const Parser, name: []const u8) ?Command {
        for (self.commands.items) |item| {
            if (mem.eql(u8, item.name, name)) return item;
        }
        return null;
    }

    /// Records `name` and returns `error.MissingValue`.
    fn failMissing(self: *Parser, name: []const u8) ParseError {
        self.missing = name;
        return error.MissingValue;
    }

    /// Writes a parse error. Call after `parse` returns a `ParseError`.
    pub fn writeError(self: *const Parser, writer: *std.Io.Writer, err: ParseError) std.Io.Writer.Error!void {
        switch (err) {
            error.MissingValue => if (self.missing) |name|
                try writer.print("missing value for {s}\n", .{name})
            else
                try writer.writeAll("missing value\n"),
            error.UnknownArgument => try writer.writeAll("unknown argument\n"),
            error.UnknownFlag => try writer.writeAll("unknown flag\n"),
            error.UnknownCommand => try writer.writeAll("unknown command\n"),
            error.InvalidValue => try writer.writeAll("invalid value\n"),
        }
    }
};

/// Returns the value attached to a long flag (`--name=value`), or `null` if
/// the token is not a long flag or has no `=` value.
fn attachedFlagValue(token: []const u8) ?[]const u8 {
    if (!mem.startsWith(u8, token, "--")) return null;
    const rest = token[2..];
    const eq = mem.indexOfScalar(u8, rest, '=') orelse return null;
    return rest[eq + 1 ..];
}

/// Returns the flag token without an attached `=value` (`--name` or `-c`).
fn flagDisplayName(token: []const u8) []const u8 {
    if (mem.startsWith(u8, token, "--")) {
        const rest = token[2..];
        if (mem.indexOfScalar(u8, rest, '=')) |eq| {
            return token[0 .. 2 + eq];
        }
    }
    return token;
}

/// Returns the printed width of a flag spec (`-s`, `--long`, or `-s, --long`).
fn flagSpecLen(flag: Flag) usize {
    var len: usize = 0;
    if (flag.short != null) len += 2;
    if (flag.short != null and flag.long != null) len += 2;
    if (flag.long) |long| len += 2 + long.len;
    return len;
}

/// Returns the longest positional argument name, used to align help text.
fn maxArgNameLen(args: []const Arg) usize {
    var width: usize = 0;
    for (args) |arg| {
        width = @max(width, arg.name.len);
    }
    return width;
}

/// Returns the longest subcommand name, used to align help text.
fn maxCommandNameLen(commands: []const Command) usize {
    var width: usize = 0;
    for (commands) |cmd| {
        width = @max(width, cmd.name.len);
    }
    return width;
}

/// Returns the longest flag spec width, used to align help text.
fn maxFlagSpecLen(flags: []const Flag) usize {
    var width: usize = 0;
    for (flags) |flag| {
        width = @max(width, flagSpecLen(flag));
    }
    return width;
}

/// Writes one usage line for a positional argument: padded `name` then `help`.
fn writeAlignedHelp(writer: *std.Io.Writer, name: []const u8, help: []const u8, width: usize) std.Io.Writer.Error!void {
    try writer.writeAll("  ");
    try writer.writeAll(name);
    if (help.len > 0) {
        var i = name.len;
        while (i < width) : (i += 1) {
            try writer.writeByte(' ');
        }
        try writer.writeAll("    ");
        try writer.writeAll(help);
    }
    try writer.writeByte('\n');
}

/// Writes one usage line for a flag: padded spec (`-s, --long`) then `help`.
fn writeFlagHelp(writer: *std.Io.Writer, flag: Flag, width: usize) std.Io.Writer.Error!void {
    try writer.writeAll("  ");
    if (flag.short) |short| {
        try writer.print("-{c}", .{short});
        if (flag.long != null) try writer.writeAll(", ");
    }
    if (flag.long) |long| {
        try writer.print("--{s}", .{long});
    }
    if (flag.help.len > 0) {
        var i = flagSpecLen(flag);
        while (i < width) : (i += 1) {
            try writer.writeByte(' ');
        }
        try writer.writeAll("    ");
        try writer.writeAll(flag.help);
    }
    try writer.writeByte('\n');
}

/// Parses `value` according to `kind` and writes it through `dest`.
/// Boolean destinations are invalid here; boolean flags are assigned
/// separately.
fn assignValue(kind: ValueKind, dest: *anyopaque, value: []const u8) ParseError!void {
    switch (kind) {
        .boolean => return error.InvalidValue,
        .string => {
            const ptr: *[]const u8 = @ptrCast(@alignCast(dest));
            ptr.* = value;
        },
        .integer => {
            const ptr: *i64 = @ptrCast(@alignCast(dest));
            ptr.* = std.fmt.parseInt(i64, value, 10) catch return error.InvalidValue;
        },
        .float => {
            const ptr: *f64 = @ptrCast(@alignCast(dest));
            ptr.* = std.fmt.parseFloat(f64, value) catch return error.InvalidValue;
        },
    }
}

/// Infers `ValueKind` from a destination pointer type. `Dest` must be a
/// mutable single-item pointer; otherwise a compile error is returned.
fn valueKindFromDest(comptime Dest: type) ValueKind {
    const info = switch (@typeInfo(Dest)) {
        .pointer => |ptr| ptr,
        else => @compileError("dest must be a pointer to a variable, got " ++ @typeName(Dest)),
    };
    if (info.size != .one) {
        @compileError("dest must be a single-item pointer, got " ++ @typeName(Dest));
    }
    if (info.is_const) {
        @compileError("dest must be a pointer to a mutable variable");
    }
    return valueKindFromType(info.child);
}

/// Maps a dest child type to `ValueKind`. Accepts `bool`, integers, floats,
/// and byte slices (`[]const u8` / `[]u8`). Other types are a compile error.
fn valueKindFromType(comptime T: type) ValueKind {
    return switch (@typeInfo(T)) {
        .bool => .boolean,
        .int, .comptime_int => .integer,
        .float, .comptime_float => .float,
        .pointer => |info| if (info.size == .slice and info.child == u8)
            .string
        else
            @compileError("invalid flag type: " ++ @typeName(T)),
        else => @compileError("invalid flag type: " ++ @typeName(T)),
    };
}
