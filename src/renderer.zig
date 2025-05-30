const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");
const raygui = @import("raygui");
const fontconfig = @cImport(@cInclude("fontconfig/fontconfig.h"));

const meta = @import("meta.zig");
const Config = @import("config.zig").Config;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);
const InputData = @import("data.zig").InputData;
const Filter = @import("data.zig").Filter;

// === START CONFIGS ===

// TODO: Make all of these constants configurable via CLI
//       and/or dotfile
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const LINE_PADDING: comptime_float = 1.0;
const HALF_LINE_PADDING: comptime_float = LINE_PADDING / 2.0;
const LINE_TEXT_OFFSET: comptime_float = 10.0;

const PROMPT_TEXT_OFFSET: comptime_float = 10.0;

// === END CONFIGS ===

const KEY_PRESS_DEBOUNCE_RATE_MS: comptime_float = 0.1;
const KEY_INITIAL_HELD_DEBOUNCE_RATE_MS: comptime_float = 0.3;
const KEY_HELD_DEBOUNCE_RATE_MS: comptime_float = 0.1;

const FontExtensions: type = enum {
    // NOTE: Don't capitalise these, they get converted to a string
    ttf,
    otf,

    pub fn matchName(
        allocator: std.mem.Allocator,
        name: []const u8,
        file: []const u8,
    ) !bool {
        inline for (std.meta.fields(@This())) |ext| {
            const file_name: []const u8 = try std.fmt.allocPrint(
                allocator,
                "{s}.{s}",
                .{ name, ext.name },
            );
            defer allocator.free(file_name);
            if (!std.mem.eql(u8, file_name, file)) {
                return true;
            }
        }
        return false;
    }
};

threadlocal var last_time: f64 = 0;
threadlocal var last_repeat: f64 = 0;

fn debounce(rate: f64) bool {
    const time: f64 = raylib.getTime();
    if (time - last_time >= rate) {
        last_time = time;
        last_repeat = time;
        return true;
    }
    return false;
}

fn debounceRepeat(initial_rate: f64, repeat_rate: f64) bool {
    const time: f64 = raylib.getTime();
    if (time - last_time >= initial_rate and time - last_repeat >= repeat_rate) {
        last_repeat = time;
        return true;
    }
    return false;
}

/// Allows initial keypress assuming `KEY_PRESS_DEBOUNCE_RATE_MS` since
/// last key press, then waits `KEY_INITIAL_HELD_DEBOUNCE_RATE_MS` if
/// key is continually held, after which subsequent triggers are
/// `KEY_HELD_DEBOUNCE_RATE_MS` apart.
fn heldDebounce(key: raylib.KeyboardKey) bool {
    if (raylib.isKeyPressed(key)) {
        return debounce(KEY_PRESS_DEBOUNCE_RATE_MS);
    } else if (raylib.isKeyDown(key)) {
        return debounceRepeat(
            KEY_INITIAL_HELD_DEBOUNCE_RATE_MS,
            KEY_HELD_DEBOUNCE_RATE_MS,
        );
    }
    return false;
}

// TODO: Support the same key bindings as dmenu
fn handleKeypress(
    _: std.mem.Allocator,
    config: *const Config,
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
    if (heldDebounce(raylib.KeyboardKey.down)) {
        input.shiftCursorLine(1, config.lines);
    } else if (heldDebounce(raylib.KeyboardKey.up)) {
        input.shiftCursorLine(-1, config.lines);
    } else if (heldDebounce(raylib.KeyboardKey.left)) {
        input.shiftBufferCol(-1);
    } else if (heldDebounce(raylib.KeyboardKey.right)) {
        input.shiftBufferCol(1);
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.tab) and debounce(KEY_PRESS_DEBOUNCE_RATE_MS)) {
        try input.selectCursorLine();
        updated_buffer = true;
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.enter) and debounce(KEY_PRESS_DEBOUNCE_RATE_MS)) {
        enter_pressed = true;
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.escape) and debounce(KEY_PRESS_DEBOUNCE_RATE_MS)) {
        input.buffer.clearAndFree();
        input.buffer_col = 0;
        enter_pressed = true;
    } else if (heldDebounce(raylib.KeyboardKey.backspace)) {
        if (input.buffer.items.len > 0) {
            _ = input.buffer.orderedRemove(input.buffer_col -| 1);
        }
        input.shiftBufferCol(-1);
        updated_buffer = true;
    }
    if (updated_buffer) {
        try input.filterLines(config.filter);
    }
    return enter_pressed;
}

fn renderHorizontal(
    _: std.mem.Allocator,
    _: *const Config,
    _: *const raylib.Font,
    _: f32,
    _: *InputData,
) anyerror!void {
    // TODO: Implement this
}

fn renderVerticalLine(
    allocator: std.mem.Allocator,
    config: *const Config,
    input: *InputData,
    font: *const raylib.Font,
    i: usize,
    line: String,
    y_pos: i32,
    line_height: i32,
    prompt_offset: f32,
) anyerror!void {
    const line_colour: raylib.Color = if (input.cursor_line == i)
        config.selected_bg
    else
        config.normal_bg;
    const text_colour: raylib.Color = if (input.cursor_line == i)
        config.selected_fg
    else
        config.normal_fg;
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
        config.font_size,
        config.font_spacing,
        text_colour,
    );
}

fn renderPrompt(
    allocator: std.mem.Allocator,
    config: *const Config,
    font: *const raylib.Font,
    font_height: f32,
) anyerror!f32 {
    // NOTE: Should this support multiple lines? If so
    //       we should return raylib.Vector2 prompt
    //       dimensions instead of just the x value.
    //       Also need to consider how user input would work
    //       and look.
    if (config.prompt == null or config.prompt.?.len == 0) {
        return 0;
    }
    const c_prompt: [:0]const u8 = try std.fmt.allocPrintZ(
        allocator,
        "{s}",
        .{config.prompt.?},
    );
    defer allocator.free(c_prompt);
    var prompt_dims = raylib.measureTextEx(
        font.*,
        c_prompt,
        config.font_size,
        config.font_spacing,
    );
    prompt_dims.x += PROMPT_TEXT_OFFSET * 2;
    const line_height: i32 = @intFromFloat(font_height + LINE_PADDING);
    raylib.drawRectangle(
        0,
        0,
        @intFromFloat(prompt_dims.x),
        line_height,
        config.prompt_bg,
    );
    raylib.drawTextEx(
        font.*,
        c_prompt,
        raylib.Vector2.init(
            PROMPT_TEXT_OFFSET,
            HALF_LINE_PADDING,
        ),
        config.font_size,
        config.font_spacing,
        config.prompt_fg,
    );
    return prompt_dims.x;
}

fn renderVertical(
    allocator: std.mem.Allocator,
    config: *const Config,
    font: *const raylib.Font,
    font_height: f32,
    input: *InputData,
) anyerror!void {
    const prompt_offset: f32 = try renderPrompt(
        allocator,
        config,
        font,
        font_height,
    );
    const int_prompt_offset: i32 = @intFromFloat(prompt_offset);
    const line_height: i32 = @intFromFloat(font_height + LINE_PADDING);
    raylib.drawRectangle(
        int_prompt_offset,
        0,
        SCREEN_WIDTH - int_prompt_offset,
        line_height,
        config.normal_bg,
    );
    raylib.drawTextCodepoints(
        font.*,
        input.buffer.items,
        raylib.Vector2.init(
            LINE_TEXT_OFFSET + prompt_offset,
            HALF_LINE_PADDING,
        ),
        config.font_size,
        config.font_spacing,
        config.normal_fg,
    );
    var buffer_col_offset: raylib.Vector2 = raylib.Vector2.init(
        0,
        config.font_size,
    );
    if (input.buffer.items.len != 0) {
        const buffer: []const c_int = if (input.buffer_col == 0)
            // FIXME: Random value, just to get height of text,
            //        but in reality we want it to be at least
            //        as large as the tallest character.
            //        Alternatively, we could just only support
            //        monospaced fonts and be done with it.
            &[_]c_int{0x34}
        else
            input.buffer.items[0..input.buffer_col];
        const c_buffer: [:0]u8 = raylib.loadUTF8(buffer);
        defer raylib.unloadUTF8(c_buffer);
        buffer_col_offset = raylib.measureTextEx(
            font.*,
            c_buffer,
            config.font_size,
            config.font_spacing,
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
        config.normal_fg,
    );
    // TODO: Check if text is longer than input field, show only truncated ending if so

    // Lines
    var y_pos: i32 = line_height;
    if (input.buffer.items.len == 0) {
        // No filtering
        const end = @min(
            input.rendered_lines_start + config.lines,
            input.lines.count(),
        );
        for (input.rendered_lines_start..end) |i| {
            // for (0..@min(args.lines, input.lines.count())) |i| {
            try renderVerticalLine(
                allocator,
                config,
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
        const end = @min(
            input.rendered_lines_start + config.lines,
            input.filtered_line_indices.items.len,
        );
        for (input.rendered_lines_start..end) |i| {
            // for (0..@min(args.lines, input.filtered_line_indices.items.len)) |i| {
            try renderVerticalLine(
                allocator,
                config,
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

fn findFont(
    allocator: std.mem.Allocator,
    config: *const Config,
) !raylib.Font {
    const font_name: []const u8 = config.font orelse {
        std.log.debug("No font supplied, defaulting to Raylib's internal font", .{});
        return raylib.getFontDefault();
    };
    const fconfig: *fontconfig.FcConfig = fontconfig.FcInitLoadConfigAndFonts() orelse {
        std.log.err("Failed to initialise fontconfig, is FONTCONFIG_PATH env var set?", .{});
        return raylib.getFontDefault();
    };
    const pattern: *fontconfig.FcPattern = fontconfig.FcNameParse(font_name.ptr) orelse {
        std.log.err("Failed to create font pattern", .{});
        return raylib.getFontDefault();
    };
    defer fontconfig.FcPatternDestroy(pattern);
    if (fontconfig.FcConfigSubstitute(
        fconfig,
        pattern,
        fontconfig.FcMatchPattern,
    ) == fontconfig.FcFalse) {
        std.log.err("Unable to configure substitute", .{});
        return raylib.getFontDefault();
    }
    fontconfig.FcDefaultSubstitute(pattern);
    var result: fontconfig.FcResult = undefined;
    const font: *fontconfig.FcPattern = fontconfig.FcFontMatch(
        fconfig,
        pattern,
        &result,
    ) orelse {
        std.log.err("Font not found: {s}", .{font_name});
        return raylib.getFontDefault();
    };
    defer fontconfig.FcPatternDestroy(font);
    var file: [*c]fontconfig.FcChar8 = undefined;
    if (fontconfig.FcPatternGetString(
        font,
        fontconfig.FC_FILE,
        0,
        &file,
    ) == fontconfig.FcResultMatch) {
        const file_path = try allocator.dupeZ(u8, file[0..std.mem.len(file)]);
        defer allocator.free(file_path);
        return try raylib.loadFontEx(
            file_path,
            @intFromFloat(config.font_size),
            null,
        );
    }
    return raylib.getFontDefault();
}

pub fn render(
    allocator: std.mem.Allocator,
    input: *InputData,
    config: Config,
) anyerror!void {
    raylib.setConfigFlags(.{
        .window_transparent = true,
        .window_undecorated = true,
    });
    raylib.setTraceLogLevel(raylib.TraceLogLevel.warning);
    var name = [_]u8{0} ** (meta.NAME.len + 1);
    raylib.initWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        try std.fmt.bufPrintZ(
            &name,
            "{s}",
            .{meta.NAME},
        ),
    );
    defer raylib.closeWindow();
    const font: raylib.Font = try findFont(
        allocator,
        &config,
    );
    defer raylib.unloadFont(font);
    const line_size: i32 = font.baseSize + @as(i32, @intFromFloat(LINE_PADDING));
    while (true) {
        const line_count: usize = if (input.buffer.items.len == 0)
            input.lines.count()
        else
            input.filtered_line_indices.items.len;
        raylib.setWindowSize(
            SCREEN_WIDTH,
            line_size * @as(i32, @intCast(1 + @min(line_count, config.lines))),
        );
        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(raylib.Color.blank);
        if (try handleKeypress(allocator, &config, input)) {
            break;
        }
        try renderVertical(
            allocator,
            &config,
            &font,
            @floatFromInt(font.baseSize),
            input,
        );
    }
}
