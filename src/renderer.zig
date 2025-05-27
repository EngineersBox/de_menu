const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const FONT_SIZE: comptime_float = 20.0;
const FONT_SPACING: comptime_float = 1.0;
const FONT_FILE_PATH = "/Users/jackkilrain/projects/assets/monocraft/Monocraft.otf";

const LINE_PADDING: comptime_int = 10;
const HALF_LINE_PADDING: comptime_int = LINE_PADDING / 2;

const BACKGROUND_COLOUR = raylib.Color.init(32, 31, 30, 0xFF);
const TRANSPARENT_COLOUR = raylib.Color.init(0, 0, 0, 0);

fn handle_keypress(
    _: std.mem.Allocator,
) anyerror!void {

}

fn render_horizontal(
    _: std.mem.Allocator,
    _: *ConcurrentArrayList(String),
    _: *const Args,
    _: *const raylib.Font,
    _: f32,
) anyerror!void {
    // TODO: Implement this
}

fn render_vertical(
    allocator: std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    args: *const Args,
    font: *const raylib.Font,
    font_height: f32,
) anyerror!void {
    // TODO: Handle prompt text on left offsetting
    //       lines on X axis by width of prompt text
    const line_height: i32 = @as(i32, @intFromFloat(font_height)) + LINE_PADDING;
    // Fuzzy finding
    raylib.drawRectangle(
        0,
        0,
        SCREEN_WIDTH,
        line_height,
        BACKGROUND_COLOUR,
    );
    raylib.drawTextEx(
        font.*,
        "|",
        raylib.Vector2.init(10, HALF_LINE_PADDING),
        FONT_SIZE,
        FONT_SPACING,
        .ray_white,
    );
    // Lines
    var y_pos: i32 = line_height;
    for (0..@min(args.lines, lines.count())) |i| {
        raylib.drawRectangle(
            0,
            y_pos,
            SCREEN_WIDTH,
            line_height,
            BACKGROUND_COLOUR,
        );
        const line: [:0]const u8 = try std.fmt.allocPrintZ(
            allocator,
            "{s}",
            .{lines.array_list.items[i].items},
        );
        defer allocator.free(line);
        raylib.drawTextEx(
            font.*,
            line,
            raylib.Vector2.init(10, @floatFromInt(y_pos + HALF_LINE_PADDING)),
            FONT_SIZE,
            FONT_SPACING,
            .ray_white,
        );
        y_pos += line_height;
    }
}

pub fn render(
    allocator: std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    args: Args,
) anyerror!void {
    raylib.initWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "de_menu",
    );
    raylib.setWindowState(.{ .window_undecorated = true });
    raylib.setTargetFPS(60);
    const font = try raylib.loadFontEx(
        FONT_FILE_PATH,
        FONT_SIZE,
        null,
    );
    defer raylib.unloadFont(font);
    const line_size: i32 = font.baseSize + LINE_PADDING;
    while (!raylib.windowShouldClose()) {
        const line_count = lines.count();
        raylib.setWindowSize(
            SCREEN_WIDTH,
            line_size * @as(i32, @intCast(@min(line_count, args.lines))),
        );
        if (line_count == 0) {
            continue;
        }
        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(TRANSPARENT_COLOUR);
        try render_vertical(
            allocator,
            lines,
            &args,
            &font,
            @floatFromInt(font.baseSize),
        );
        try handle_keypress(allocator);
    }
}
