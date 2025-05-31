const std = @import("std");
const root = @import("root");
const known_folders = @import("known-folders");
// const microwave = @import("microwave");
const clap = @import("clap");

const PATH_SEP: *const [1:0]u8 = std.fs.path.sep_str;
const CONFIG_PATH: []const u8 = PATH_SEP ++ "de_menu" ++ PATH_SEP ++ "config.toml";

pub const Config: type = struct {
    allocator: std.mem.Allocator,

    lines: usize = 20,
    monitor: ?usize = null,
    prompt: ?[]const u8 = null,
    font: ?[]const u8 = null,
    font_size: usize = 20,

    pub fn initFromStdin(allocator: std.mem.Allocator) anyerror!?@This() {
        // TODO: Support all dmenu options
        const params = comptime clap.parseParamsComptime(
            \\ -h, --help
            \\ -l, --lines <usize>        lists items vertically, with the given number of lines
            \\ -m, --monitor <usize>      monitor to render to, leave unset to choose monitor that holds current focus
            \\ -p, --prompt <str>         defines the prompt to be displayed to the left of the input field
            \\ -f, --font <str>           font to use, must be in a fontconfig discoverable location
            \\ -s, --font_size <usize>    size of the font, defaults to 20
        );
        var diag = clap.Diagnostic{};
        var res = clap.parse(
            clap.Help,
            &params,
            clap.parsers.default,
            .{
                .diagnostic = &diag,
                .allocator = allocator,
            },
        ) catch |err| {
            // Report useful error and exit.
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
        };
        defer res.deinit();
        if (res.args.help != 0) {
            var writer = std.io.getStdErr().writer();
            try writer.writeAll("Usage: de_menu [options...]\nOptions:\n");
            try clap.help(
                writer,
                clap.Help,
                &params,
                .{},
            );
            return null;
        }
        var config: @This() = .{
            .allocator = allocator,
        };
        if (res.args.lines) |lines| {
            config.lines = lines;
        }
        if (res.args.monitor) |monitor| {
            config.monitor = monitor;
        }
        if (res.args.prompt) |prompt| {
            config.prompt = try allocator.dupe(u8, prompt);
        }
        if (res.args.font) |font| {
            config.font = try allocator.dupe(u8, font);
        }
        if (res.args.font_size) |font_size| {
            config.font_size = font_size;
        }
        return config;
    }

    pub fn deinit(self: *@This()) void {
        if (self.prompt) |prompt| {
            self.allocator.free(prompt);
        }
        if (self.font) |font| {
            self.allocator.free(font);
        }
    }
};
