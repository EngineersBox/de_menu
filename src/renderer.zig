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
const FONT_FILE_PATH = "/Users/jackkilrain/projects/assets/monocraft/Monocraft.otf";

const LINE_PADDING: comptime_int = 10;
const HALF_LINE_PADDING: comptime_int = LINE_PADDING / 2;

const BACKGROUND_COLOUR = raylib.Color.init(32, 31, 30, 0xFF);
const TRANSPARENT_COLOUR = raylib.Color.init(0, 0, 0, 0);

fn render_no_prompt(
    allocator: std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    args: *const Args,
    font: *const raylib.Font,
    font_height: f32,
) anyerror!void {
    const line_height: i32 = @as(i32, @intFromFloat(font_height + LINE_PADDING));
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
        raylib.drawTextEx(
            font.*,
            line,
            raylib.Vector2.init(10, HALF_LINE_PADDING),
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
    // const font = try raylib.getFontDefault();
    defer raylib.unloadFont(font);
    const font_dims = raylib.measureTextEx(
        font,
        "A",
        FONT_SIZE,
        FONT_SPACING,
    );
    while (!raylib.windowShouldClose()) {
        const line_count = lines.count();
        raylib.setWindowSize(
            SCREEN_WIDTH,
            @as(i32, @intFromFloat((font_dims.y + LINE_PADDING) * @as(f32, @floatFromInt(@min(line_count, args.lines))))),
        );
        if (line_count == 0) {
            continue;
        }
        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(TRANSPARENT_COLOUR);
        if (args.prompt == null) {
            try render_no_prompt(
                allocator,
                lines,
                &args,
                &font,
                font_dims.y,
            );
        }
    }
}
