const std = @import("std");
const clap = @import("clap");

pub const Args: type = struct {
    allocator: *const std.mem.Allocator,
    // TODO: Add the rest of dmenu options
    lines: usize,
    prompt: ?[]const u8,

    pub fn fromStdinAllocated(allocator: std.mem.Allocator) anyerror!@This() {
        const params = comptime clap.parseParamsComptime(
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
        var args = Args{
            .allocator = &allocator,
            .lines = 20,
            .prompt = null,
        };
        if (res.args.lines) |lines| {
            args.lines = lines;
        }
        if (res.args.prompt) |prompt| {
            args.prompt = try allocator.dupe(u8, prompt);
        }
        return args;
    }

    pub fn deinit(self: *@This()) void {
        if (self.prompt) |prompt| {
            self.allocator.free(prompt);
        }
    }

    pub inline fn isVertical(self: *const @This()) bool {
        return self.lines > 0;
    }
};
