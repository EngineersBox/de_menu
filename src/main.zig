const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");
const raygui = @import("raygui");
const KnownFolders = @import("known-folders");

const render = @import("renderer.zig").render;
const Config = @import("config.zig").Config;
const InputData = @import("data.zig").InputData;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);

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
    input: *InputData,
    should_terminate: *volatile bool,
) anyerror!void {
    var reader = stdin.reader();
    defer stdin.close();
    while (!should_terminate.*) {
        var line: String = String.init(allocator);
        reader.streamUntilDelimiter(
            line.writer(),
            DELIMITER,
            null,
        ) catch |err| switch (err) {
            error.EndOfStream => break, 
            error.StreamTooLong => {
                // Make do with what we have
                @panic("Input stream too long");
            },
            else => {
                @panic("Unknown error");
            },
        };
        // I forgot about this originally, this gist saved me some pain and jogged my
        // memory: https://gist.github.com/doccaico/4e15cacaf06279ab29c8aacb3f2c9478
        const trimmed_line = if (builtin.target.os.tag == .windows)
            // Nuke prefixing newlines, since we match a EOL
            // as CR on windows, which follows with LF after.
            return line.fromOwnedSlice(
                allocator,
                std.mem.trimLeft(
                    u8,
                    try line.toOwnedSlice(),
                    "\n"
                ),
            )
        else
            line;
        try input.lines.append(trimmed_line);
    }
}

fn writeBufferToStdout(input: *const InputData) anyerror!void {
    if (input.buffer.items.len == 0) {
        // Nothing was selected, nothing to write out
        return;
    }
    var stdout: std.fs.File = std.io.getStdOut();
    const buffer: [:0]const u8 = raylib.loadUTF8(input.buffer.items);
    try stdout.writeAll(buffer);
    stdout.close();
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
    var input: InputData = InputData.new(allocator);
    defer input.deinit();
    var config: Config = try Config.initFromStdin(allocator) orelse return;
    defer config.deinit();
    var run_thread: std.Thread = undefined;
    run_thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        run,
        .{ allocator, std.io.getStdIn(), &input, &should_terminate },
    );
    run_thread.detach();
    try render(allocator, &input, config);
    try writeBufferToStdout(&input);
}
