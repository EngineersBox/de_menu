const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const FONT_SIZE: comptime_float = 20.0;
const FONT_SPACING: comptime_float = 5.0;
const FONT_FILE_PATH = "/Users/jackkilrain/Library/Fonts/Monocraft.ttc";

const BACKGROUND_COLOUR = raylib.Color.init(32, 31, 30, 0xFF);
const TRANSPARENT_COLOUR = raylib.Color.init(0, 0, 0, 0);

pub fn render(
    allocator: *std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    args: *Args,
    font_height
)


fn render(
    allocator: *std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    args: Args,
) anyerror!void {
    raylib.initWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "Raylib",
    );
    defer raylib.closeWindow();
    raylib.setWindowState(.{ .window_undecorated = true });
    raylib.setTargetFPS(60);

    while (!raylib.windowShouldClose()) {
        if (lines.count() == 0) {
            continue;
        }
        raylib.beginDrawing();
        defer raylib.endDrawing();
    }
}
