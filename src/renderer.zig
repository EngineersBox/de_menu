const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);
const InputData = @import("data.zig").InputData;
const Filter = @import("data.zig").Filter;
const Filters = @import("data.zig").Filters;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const FONT_SIZE: comptime_float = 20.0;
const FONT_SPACING: comptime_float = 1.0;
const FONT_FILE_PATH = "/Users/jackkilrain/projects/assets/monocraft/Monocraft.otf";
const FONT_COLOUR = raylib.Color.ray_white;

const LINE_PADDING: comptime_float = 1.0;
const HALF_LINE_PADDING: comptime_float = LINE_PADDING / 2.0;
const LINE_FILTER: Filter = Filters.stringContains;

const BACKGROUND_COLOUR = raylib.Color.init(32, 31, 30, 0xFF);
const SELECTED_LINE_COLOUR = raylib.Color.dark_blue;

const KEY_DEBOUNCE_RATE_MS: comptime_float = 0.05;
const MOVE_DEBOUNCE_RATE_MS: comptime_float = 0.1;

threadlocal var last_time: f64 = 0;

fn handleKeypress(
    _: std.mem.Allocator,
    args: *const Args,
    input: *InputData,
) anyerror!void {
    var utf8_char: i32 = raylib.getCharPressed();
    var updated_buffer: bool = utf8_char > 0;
    while (utf8_char > 0) {
        if (utf8_char >= 32 and utf8_char <= 125) {
            try input.buffer.append(utf8_char);
        }
        utf8_char = raylib.getCharPressed();
    }
    const next_key: raylib.KeyboardKey = if (args.isVertical()) raylib.KeyboardKey.down else raylib.KeyboardKey.right;
    const prev_key: raylib.KeyboardKey = if (args.isVertical()) raylib.KeyboardKey.up else raylib.KeyboardKey.left;
    if (raylib.isKeyDown(next_key) and raylib.getTime() - last_time >= MOVE_DEBOUNCE_RATE_MS) {
        last_time = raylib.getTime();
        input.shiftCursorLine(1);
    } else if (raylib.isKeyDown(prev_key) and raylib.getTime() - last_time >= MOVE_DEBOUNCE_RATE_MS) {
        last_time = raylib.getTime();
        input.shiftCursorLine(-1);
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.tab)) {
        last_time = raylib.getTime();
        try input.selectCursorLine();
    } else if (raylib.isKeyDown(raylib.KeyboardKey.backspace) and raylib.getTime() - last_time >= KEY_DEBOUNCE_RATE_MS) {
        last_time = raylib.getTime();
        _ = input.buffer.pop();
        updated_buffer = true;
    }
    if (updated_buffer) {
        try input.filterLines(LINE_FILTER);
    }
}

fn renderHorizontal(
    _: std.mem.Allocator,
    _: *const Args,
    _: *const raylib.Font,
    _: f32,
    _: *InputData,
) anyerror!void {
    // TODO: Implement this
}

fn renderVerticalLine(
    allocator: std.mem.Allocator,
    input: *InputData,
    font: *const raylib.Font,
    i: usize,
    line: String,
    y_pos: i32,
    line_height: i32,
) anyerror!void {
    const line_colour: raylib.Color = if (input.cursor_line == i)
        SELECTED_LINE_COLOUR
    else
        BACKGROUND_COLOUR;
    raylib.drawRectangle(
        0,
        y_pos,
        SCREEN_WIDTH,
        line_height,
        line_colour,
    );
    const c_line: [:0]const u8 = try std.fmt.allocPrintZ(
        allocator,
        "{s}",
        .{line.items},
    );
    defer allocator.free(c_line);
    raylib.drawTextEx(
        font.*,
        c_line,
        raylib.Vector2.init(10, @as(f32, @floatFromInt(y_pos)) + HALF_LINE_PADDING),
        FONT_SIZE,
        FONT_SPACING,
        FONT_COLOUR,
    );
}

fn renderVertical(
    allocator: std.mem.Allocator,
    args: *const Args,
    font: *const raylib.Font,
    font_height: f32,
    input: *InputData,
) anyerror!void {
    // TODO: Handle prompt text on left offsetting
    //       lines on X axis by width of prompt text
    const line_height: i32 = @intFromFloat(font_height + LINE_PADDING);
    // Fuzzy finding
    raylib.drawRectangle(
        0,
        0,
        SCREEN_WIDTH,
        line_height,
        BACKGROUND_COLOUR,
    );
    raylib.drawTextCodepoints(
        font.*,
        input.buffer.items,
        raylib.Vector2.init(10, HALF_LINE_PADDING),
        FONT_SIZE,
        FONT_SPACING,
        FONT_COLOUR,
    );
    // TODO: Check if text is longer than input field, show only truncated ending if so

    // Lines
    var y_pos: i32 = line_height;
    if (input.buffer.items.len == 0) {
        // No filtering
        for (0..@min(args.lines, input.lines.count())) |i| {
            try renderVerticalLine(
                allocator,
                input,
                font,
                i,
                input.lines.get(i),
                y_pos,
                line_height,
            );
            y_pos += line_height;
        }
    } else {
        // Filtered
        for (0..@min(args.lines, input.filtered_line_indices.items.len)) |i| {
            try renderVerticalLine(
                allocator,
                input,
                font,
                i,
                input.lines.get(input.filtered_line_indices.items[i]),
                y_pos,
                line_height,
            );
            y_pos += line_height;
        }
    }
}

pub fn render(
    allocator: std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    args: Args,
) anyerror!void {
    raylib.setConfigFlags(.{ .window_transparent = true });
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
    const line_size: i32 = font.baseSize + @as(i32, @intFromFloat(LINE_PADDING));
    var input: InputData = InputData.new(allocator, lines);
    defer input.deinit();
    while (!raylib.windowShouldClose()) {
        const line_count = if (input.buffer.items.len == 0)
            input.lines.count()
        else
            input.filtered_line_indices.items.len;
        raylib.setWindowSize(
            SCREEN_WIDTH,
            line_size * @as(i32, @intCast(1 + @min(line_count, args.lines))),
        );
        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(raylib.Color.blank);
        try handleKeypress(allocator, &args, &input);
        try renderVertical(
            allocator,
            &args,
            &font,
            @floatFromInt(font.baseSize),
            &input,
        );
    }
}
