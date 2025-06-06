const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");
const raygui = @import("raygui");
const KnownFolders = @import("known-folders");

const render = @import("renderer.zig").render;
const Config = @import("config.zig").Config;
const Data = @import("data.zig");
const CString = Data.CString;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;

const DELIMITER: comptime_int = if (builtin.target.os.tag == .windows) '\r' else '\n';

// This is dynamically updated from used spots in this repo
// to set required configurations before using
pub const known_folders_config: KnownFolders.KnownFolderConfig = .{
    .xdg_force_default = false,
    .xdg_on_mac = true,
};

fn run(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    input: *Data,
    config: *const Config,
    should_terminate: *volatile bool,
) anyerror!void {
    defer stdin.close();
    var reader = stdin.reader();
    var found_eof: bool = false;
    while (!should_terminate.* and !found_eof) {
        var line = std.ArrayList(u8).init(allocator);
        reader.streamUntilDelimiter(
            line.writer(),
            DELIMITER,
            null,
        ) catch |err| switch (err) {
            error.EndOfStream => {
                // Assume the line has data, break later
                found_eof = true;
            },
            else => {
                const msg: []const u8 = try std.fmt.allocPrint(allocator, "Error while reading stdin: {}", .{err});
                defer allocator.free(msg);
                @panic(msg);
            },
        };
        // I forgot about this originally, this gist saved me some pain and jogged my
        // memory: https://gist.github.com/doccaico/4e15cacaf06279ab29c8aacb3f2c9478
        if (builtin.target.os.tag == .windows) {
            // Nuke prefixing newlines, since we match a EOL
            // as CR on windows, which follows with LF after.
            var trimmed_line = std.ArrayList(u8).init(allocator);
            errdefer line.deinit();
            try trimmed_line.appendSlice(std.mem.trimLeft(
                u8,
                try line.toOwnedSlice(),
                "\n"
            ));
            line.deinit();
            line = trimmed_line;
        }
        defer line.deinit();
        if (line.items.len == 0) {
            continue;
        }
        // NOTE: Pre-convert to a CString to avoid needing to do it
        //       repeatedly during the render loop
        try input.appendLine(try std.fmt.allocPrintZ(
            allocator,
            "{s}",
            .{line.items},
        ), config);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const allocator: std.mem.Allocator = gpa.allocator();
    var should_terminate: bool = false;
    // Must happen after run_thread join to avoid
    // usage of deinitialised ConcurrentArrayList
    // during thread termination
    defer should_terminate = true;
    var input: Data = try Data.new(allocator);
    defer input.deinit();
    var config: Config = try Config.initFromStdin(allocator) orelse return;
    defer config.deinit();
    var run_thread: std.Thread = undefined;
    run_thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        run,
        .{ allocator, std.io.getStdIn(), &input, &config, &should_terminate },
    );
    run_thread.detach();
    try render(allocator, &input, &config);
    std.process.cleanExit();
}
