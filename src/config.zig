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
    prompt: ?[]const u8 = null,

    pub fn initFromStdin(allocator: std.mem.Allocator) anyerror!?@This() {
        const params = comptime clap.parseParamsComptime(
            \\ -h, --help
            \\ -l, --lines <usize>        lists items vertically, with the given number of lines
            \\ -p, --prompt <str>         defines the prompt to be displayed to the left of the input field
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
        if (res.args.prompt) |prompt| {
            config.prompt = try allocator.dupe(u8, prompt);
        }
        return config;
    }

    pub fn deinit(self: *@This()) void {
        if (self.prompt) |prompt| {
            self.allocator.free(prompt);
        }
    }
};
