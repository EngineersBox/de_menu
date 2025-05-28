const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");
const raygui = @import("raygui");

const render = @import("renderer.zig").render;
const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);

const DELIMITER: comptime_int = if (builtin.target.os.tag == .windows) '\r' else '\n';

fn run(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    lines: *ConcurrentArrayList(String),
    should_terminate: *volatile bool,
) anyerror!void {
    var reader = stdin.reader();
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
        // I forgot about this originall, this gist saved the pain and jogged my
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
        try lines.append(trimmed_line);
    }
    std.debug.print("Run thread done\n", .{});
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
    const allocator = gpa.allocator();
    var args: Args = try Args.fromStdinAllocated(allocator);
    var lines = ConcurrentArrayList(String).init(allocator);
    var should_terminate: bool = false;
    var run_thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        run,
        .{ allocator, std.io.getStdIn(), &lines, &should_terminate },
    );
    defer {
        should_terminate = true;
        run_thread.join();
        // Must happen after join to avoid usage
        // of deinitialised ConcurrentArrayList
        // during thread termination
        args.deinit();
        lines.rwlock.lock();
        for (lines.array_list.items) |*line| {
            line.*.deinit();
        }
        lines.rwlock.unlock();
        lines.deinit();
    }
    try render(allocator, &lines, args);
}
