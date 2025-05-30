const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");
const raygui = @import("raygui");
const known_folders = @import("known-folders");

const Config = @import("config.zig").Config;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);
const InputData = @import("data.zig").InputData;
const Filter = @import("data.zig").Filter;
const Filters = @import("data.zig").Filters;

// === START CONFIGS ===

// TODO: Make all of these constants configurable via CLI
//       and/or dotfile
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const FONT_SIZE: comptime_float = 20.0;
const FONT_SPACING: comptime_float = 1.0;
const FONT_NAME = "Monocraft";
const FONT_COLOUR = raylib.Color.ray_white;

const LINE_PADDING: comptime_float = 1.0;
const HALF_LINE_PADDING: comptime_float = LINE_PADDING / 2.0;
const LINE_FILTER: Filter = Filters.contains;
const LINE_TEXT_OFFSET: comptime_float = 10.0;

const PROMPT_TEXT_OFFSET: comptime_float = 10.0;
const PROMPT_COLOUR = raylib.Color.dark_blue;

const BACKGROUND_COLOUR = raylib.Color.init(32, 31, 30, 0xFF);
const SELECTED_LINE_COLOUR = raylib.Color.dark_blue;

const KEY_PRESS_DEBOUNCE_RATE_MS: comptime_float = 0.1;
const KEY_INITIAL_HELD_DEBOUNCE_RATE_MS: comptime_float = 0.3;
const KEY_HELD_DEBOUNCE_RATE_MS: comptime_float = 0.1;

// === END CONFIGS ===

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
        try input.filterLines(LINE_FILTER);
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
        const end = @min(
            input.rendered_lines_start + config.lines,
            input.lines.count(),
        );
        for (input.rendered_lines_start..end) |i| {
            // for (0..@min(args.lines, input.lines.count())) |i| {
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
        const end = @min(
            input.rendered_lines_start + config.lines,
            input.filtered_line_indices.items.len,
        );
        for (input.rendered_lines_start..end) |i| {
            // for (0..@min(args.lines, input.filtered_line_indices.items.len)) |i| {
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

// inline fn fontPaths(allocator: std.mem.Allocator) anyerror![][]const u8 {
//     switch (builtin.os.tag) {
//         .windows => {
//              return .{
//                 try known_folders.getPath(
//                     allocator,
//                     known_folders.KnownFolder.fonts,
//                 ) orelse .{},
//             };
//         },
//         .macos => {
//             const home = std.process.getEnvVarOwned(allocator, "HOME");
//             defer allocator.free(home);
//             return .{
//                 std.mem.concat(allocator, u8, .{
//                     home,
//                     "/Library/Fonts"
//                 }),
//                 std.mem.concat(allocator, u8, .{
//                     home,
//                     "/Library/Fonts"
//                 }),
//             };
//         },
//     }
// }

const fontconfig = @cImport(@cInclude("fontconfig/fontconfig.h"));

fn findFont(
    allocator: std.mem.Allocator,
    font_name: ?[]const u8,
    font_size: i32,
) !raylib.Font {
    const name: []const u8 = font_name orelse {
        std.log.debug("No font supplied, defaulting to Raylib's internal font", .{});
        return raylib.getFontDefault();
    };
    const config: *fontconfig.FcConfig = fontconfig.FcInitLoadConfigAndFonts() orelse {
        std.log.err("Failed to initialise fontconfig, is FONTCONFIG_PATH env var set?", .{});
        return raylib.getFontDefault();
    };
    const pattern: *fontconfig.FcPattern = fontconfig.FcNameParse(name.ptr) orelse {
        std.log.err("Failed to create font pattern", .{});
        return raylib.getFontDefault();
    };
    defer fontconfig.FcPatternDestroy(pattern);
    if (fontconfig.FcConfigSubstitute(
        config,
        pattern,
        fontconfig.FcMatchPattern,
    ) == fontconfig.FcFalse) {
        std.log.err("Unable to configure substitute", .{});
        return raylib.getFontDefault();
    }
    fontconfig.FcDefaultSubstitute(pattern);
    var result: fontconfig.FcResult = undefined;
    const font: *fontconfig.FcPattern = fontconfig.FcFontMatch(
        config,
        pattern,
        &result,
    ) orelse {
        std.log.err("Font not found: {s}", .{name});
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
            font_size,
            null,
        );
    }
    return raylib.getFontDefault();

    // const set: *fontconfig.FcObjectSet = fontconfig.FcObjectSetBuild(
    //     @as([*c]const u8, fontconfig.FC_FAMILY),
    //     @as([*c]const u8, fontconfig.FC_STYLE),
    //     @as([*c]const u8, fontconfig.FC_LANG),
    //     @as([*c]const u8, fontconfig.FC_FILE),
    //     @as([*c]const u8, null),
    // );
    // const font_set: [*c]fontconfig.FcFontSet = fontconfig.FcFontList(
    //     config,
    //     pattern,
    //     set,
    // );
    // defer fontconfig.FcFontSetDestroy(font_set);
    // if (font_set == null) {
    //     return;
    // }
    // for (0..@intCast(font_set.*.nfont)) |i| {
    //     const font: *fontconfig.FcPattern = font_set.*.fonts[i] orelse {
    //         std.log.err("Expected font present, but found nothing at index {d}", .{i});
    //         return;
    //     };
    //     var file: [*c]fontconfig.FcChar8 = undefined;
    //     var style: [*c]fontconfig.FcChar8 = undefined;
    //     var family: [*c]fontconfig.FcChar8 = undefined;
    //     if (fontconfig.FcPatternGetString(font, fontconfig.FC_FILE, 0, &file) == fontconfig.FcResultMatch
    //     and fontconfig.FcPatternGetString(font, fontconfig.FC_FAMILY, 0, &family) == fontconfig.FcResultMatch
    //     and fontconfig.FcPatternGetString(font, fontconfig.FC_STYLE, 0, &style) == fontconfig.FcResultMatch) {
    //         std.log.info("File: {s} (Family: {s}, Style: {s})", .{
    //             file[0..std.mem.len(file)],
    //             family[0..std.mem.len(family)],
    //             style[0..std.mem.len(style)],
    //         });
    //     }
    // }
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
    raylib.initWindow(
        SCREEN_WIDTH,
        SCREEN_HEIGHT,
        "de_menu",
    );
    defer raylib.closeWindow();
    const font: raylib.Font = try findFont(
        allocator,
        FONT_NAME,
        @intFromFloat(FONT_SIZE),
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
