const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);
const InputData = @import("data.zig").InputData;
const Filter = @import("data.zig").Filter;
const Filters = @import("data.zig").Filters;

// TODO: Make all of these constants configurable via CLI
//       and/or dotfile
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const FONT_SIZE: comptime_float = 20.0;
const FONT_SPACING: comptime_float = 1.0;
const FONT_FILE_PATH = "/Users/jackkilrain/projects/assets/monocraft/Monocraft.otf";
const FONT_COLOUR = raylib.Color.ray_white;

const LINE_PADDING: comptime_float = 1.0;
const HALF_LINE_PADDING: comptime_float = LINE_PADDING / 2.0;
// TODO: Fix the contains filtering, it leaves elements
//       visible that dont match.
const LINE_FILTER: Filter = Filters.contains;
const LINE_TEXT_OFFSET: comptime_float = 10.0;

const PROMPT_TEXT_OFFSET: comptime_float = 10.0;
const PROMPT_COLOUR = raylib.Color.dark_blue;

const BACKGROUND_COLOUR = raylib.Color.init(32, 31, 30, 0xFF);
const SELECTED_LINE_COLOUR = raylib.Color.dark_blue;

const INITIAL_DEBOUNCE_RATE_MS: comptime_float = 1.0;
const KEY_DEBOUNCE_RATE_MS: comptime_float = 0.1;
const MOVE_DEBOUNCE_RATE_MS: comptime_float = 0.1;

threadlocal var last_time: f64 = 0;
threadlocal var last_initial: f64 = 0;

fn debounce(rate: f64) bool {
    const time: f64 = raylib.getTime();
    if (time - last_time >= rate) {
        last_time = time;
        return true;
    }
    return false;
}

fn debounceInitial(rate: f64) bool {
    const time: f64 = raylib.getTime();
    if (last_time - time >= rate) {
        last_time = time;
        last_initial = time;
        return true;
    }
    return false;
}

fn handleKeypress(
    _: std.mem.Allocator,
    input: *InputData,
) anyerror!bool {
    var unicode_char: i32 = raylib.getCharPressed();
    var updated_buffer: bool = unicode_char > 0;
    while (unicode_char > 0) {
        if (unicode_char >= 32 and unicode_char <= 125) {
            try input.buffer.insert(input.buffer_col, unicode_char);
            input.shiftBufferCol(1);
        }
        unicode_char = raylib.getCharPressed();
    }
    var enter_pressed: bool = false;
    if (raylib.isKeyDown(raylib.KeyboardKey.down) and debounce(MOVE_DEBOUNCE_RATE_MS)) {
        input.shiftCursorLine(1);
    } else if (raylib.isKeyDown(raylib.KeyboardKey.up) and debounce(MOVE_DEBOUNCE_RATE_MS)) {
        input.shiftCursorLine(-1);
    } else if (raylib.isKeyDown(raylib.KeyboardKey.left) and debounce(MOVE_DEBOUNCE_RATE_MS)) {
        input.shiftBufferCol(-1);
    } else if (raylib.isKeyDown(raylib.KeyboardKey.right) and debounce(MOVE_DEBOUNCE_RATE_MS)) {
        input.shiftBufferCol(1);
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.tab) and debounce(KEY_DEBOUNCE_RATE_MS)) {
        try input.selectCursorLine();
        updated_buffer = true;
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.enter) and debounce(KEY_DEBOUNCE_RATE_MS)) {
        enter_pressed = true;
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.escape) and debounce(KEY_DEBOUNCE_RATE_MS)) {
        input.buffer.clearAndFree();
        input.buffer_col = 0;
        enter_pressed = true;
    }
    if (input.buffer_col > 0) {
        if (raylib.isKeyPressed(raylib.KeyboardKey.backspace) and debounceInitial(KEY_DEBOUNCE_RATE_MS)) {
            _ = input.buffer.orderedRemove(input.buffer_col -| 1);
            input.shiftBufferCol(-1);
            updated_buffer = true;
        } else if (raylib.isKeyDown(raylib.KeyboardKey.backspace) and raylib.getTime() - last_initial >= INITIAL_DEBOUNCE_RATE_MS and debounce(KEY_DEBOUNCE_RATE_MS)) {
            _ = input.buffer.orderedRemove(input.buffer_col -| 1);
            input.shiftBufferCol(-1);
            updated_buffer = true;
        }
    }
    if (raylib.isKeyReleased(raylib.KeyboardKey.backspace)) {
        last_time = raylib.getTime();
    }

    if (updated_buffer) {
        try input.filterLines(LINE_FILTER);
    }
    return enter_pressed;
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
    prompt_offset: f32,
) anyerror!void {
    const line_colour: raylib.Color = if (input.cursor_line == i)
        SELECTED_LINE_COLOUR
    else
        BACKGROUND_COLOUR;
    const int_prompt_offset: i32 = @intFromFloat(prompt_offset);
    raylib.drawRectangle(
        int_prompt_offset,
        y_pos,
        SCREEN_WIDTH - int_prompt_offset,
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
        raylib.Vector2.init(
            LINE_TEXT_OFFSET + prompt_offset,
            @as(f32, @floatFromInt(y_pos)) + HALF_LINE_PADDING,
        ),
        FONT_SIZE,
        FONT_SPACING,
        FONT_COLOUR,
    );
}

fn renderPrompt(
    allocator: std.mem.Allocator,
    args: *const Args,
    font: *const raylib.Font,
    font_height: f32,
) anyerror!f32 {
    // TODO: Should this support multiple lines? If so
    //       we should return raylib.Vector2 prompt
    //       dimensions instead of just the x value.
    //       Also need to consider how user input would work
    //       and look.
    if (args.prompt == null or args.prompt.?.len == 0) {
        return 0;
    }
    const c_prompt: [:0]const u8 = try std.fmt.allocPrintZ(
        allocator,
        "{s}",
        .{args.prompt.?},
    );
    defer allocator.free(c_prompt);
    var prompt_dims = raylib.measureTextEx(
        font.*,
        c_prompt,
        FONT_SIZE,
        FONT_SPACING,
    );
    prompt_dims.x += PROMPT_TEXT_OFFSET * 2;
    const line_height: i32 = @intFromFloat(font_height + LINE_PADDING);
    raylib.drawRectangle(
        0,
        0,
        @intFromFloat(prompt_dims.x),
        line_height,
        PROMPT_COLOUR,
    );
    raylib.drawTextEx(
        font.*,
        c_prompt,
        raylib.Vector2.init(
            PROMPT_TEXT_OFFSET,
            HALF_LINE_PADDING,
        ),
        FONT_SIZE,
        FONT_SPACING,
        FONT_COLOUR,
    );
    return prompt_dims.x;
}

fn renderVertical(
    allocator: std.mem.Allocator,
    args: *const Args,
    font: *const raylib.Font,
    font_height: f32,
    input: *InputData,
) anyerror!void {
    const prompt_offset: f32 = try renderPrompt(
        allocator,
        args,
        font,
        font_height,
    );
    const int_prompt_offset: i32 = @intFromFloat(prompt_offset);
    const line_height: i32 = @intFromFloat(font_height + LINE_PADDING);
    // Fuzzy finding
    raylib.drawRectangle(
        int_prompt_offset,
        0,
        SCREEN_WIDTH - int_prompt_offset,
        line_height,
        BACKGROUND_COLOUR,
    );
    raylib.drawTextCodepoints(
        font.*,
        input.buffer.items,
        raylib.Vector2.init(
            LINE_TEXT_OFFSET + prompt_offset,
            HALF_LINE_PADDING,
        ),
        FONT_SIZE,
        FONT_SPACING,
        FONT_COLOUR,
    );
    var buffer_col_offset: raylib.Vector2 = raylib.Vector2.init(
        0,
        FONT_SIZE,
    );
    if (input.buffer.items.len != 0) {
        const buffer: []const c_int = if (input.buffer_col == 0)
            &[_]c_int{0x34}
        else
            input.buffer.items[0..input.buffer_col];
        const c_buffer: [:0]u8 = raylib.loadUTF8(buffer);
        defer raylib.unloadUTF8(c_buffer);
        buffer_col_offset = raylib.measureTextEx(
            font.*,
            c_buffer,
            FONT_SIZE,
            FONT_SPACING,
        );
        if (input.buffer_col == 0) {
            buffer_col_offset.x = 0;
        }
    }
    raylib.drawLineEx(
        raylib.Vector2.init(
            LINE_TEXT_OFFSET + prompt_offset + buffer_col_offset.x,
            HALF_LINE_PADDING,
        ),
        raylib.Vector2.init(
            LINE_TEXT_OFFSET + prompt_offset + buffer_col_offset.x,
            HALF_LINE_PADDING + buffer_col_offset.y,
        ),
        1.0,
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
                prompt_offset,
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
                prompt_offset,
            );
            y_pos += line_height;
        }
    }
}

pub fn render(
    allocator: std.mem.Allocator,
    input: *InputData,
    args: Args,
) anyerror!void {
    raylib.setConfigFlags(.{
        .window_transparent = true,
        .window_undecorated = true,
    });
    raylib.setTraceLogLevel(raylib.TraceLogLevel.warning);
    raylib.initWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "de_menu",
    );
    defer raylib.closeWindow();
    const font = try raylib.loadFontEx(
        FONT_FILE_PATH,
        FONT_SIZE,
        null,
    );
    defer raylib.unloadFont(font);
    const line_size: i32 = font.baseSize + @as(i32, @intFromFloat(LINE_PADDING));
    while (true) {
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
        if (try handleKeypress(allocator, input)) {
            break;
        }
        try renderVertical(
            allocator,
            &args,
            &font,
            @floatFromInt(font.baseSize),
            input,
        );
    }
}
