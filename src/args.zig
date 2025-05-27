const std = @import("std");
const clap = @import("clap");

pub const Args: type = struct {
    // TODO: Add the rest of dmenu options
    lines: usize,
    prompt: ?[]const u8,

    pub fn from_stdin_allocated(allocator: *std.mem.Allocator) anyerror!@This() {
        const params = comptime clap.parseParamsComptime(
            \\ -l, --lines <usize>        lists items vertically, with the given number of lines
            \\ -p, --prompt <str>         defines the prompt to be displayed to the left of the input field
        );
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .diagnostic = &diag,
            .allocator = allocator,
        }) catch |err| {
            // Report useful error and exit.
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
        };
        defer res.deinit();
        var args = Args {
            .lines = 20,
            .prompt = null
        };
        if (res.args.help != 0) {
            std.debug.print("--help\n", .{});
        }
        if (res.args.lines) |lines| {
            args.lines = lines;
        }
        if (res.args.prompt) |prompt| {
            args.prompt = prompt;
        }
        return args;
    }
};

