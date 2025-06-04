const std = @import("std");
const raylib = @import("raylib");

const Config = @import("config.zig").Config;
const Data = @import("data.zig");

const KEY_PRESS_DEBOUNCE_RATE_MS: comptime_float = 0.1;
const KEY_INITIAL_HELD_DEBOUNCE_RATE_MS: comptime_float = 0.3;
const KEY_HELD_DEBOUNCE_RATE_MS: comptime_float = 0.1;

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

pub const InputState: type = enum {
    // If the buffer has data, write it to
    // stdout, then exit
    WRITE_EXIT,
    // Write the buffer to stdout,
    // clear the buffer then continue
    // to execute normally
    WRITE_CONTINUE,
    // Continue execution
    CONTINUE,
};

// TODO: Support the same key bindings as dmenu
pub fn handleKeypress(
    config: *const Config,
    input: *Data,
) anyerror!InputState {
    var unicode_char: i32 = raylib.getCharPressed();
    var updated_buffer: bool = unicode_char > 0;
    while (unicode_char > 0) {
        if (unicode_char >= 32 and unicode_char <= 125) {
            try input.buffer.insert(input.buffer_col, unicode_char);
            input.shiftBufferCol(1);
        }
        unicode_char = raylib.getCharPressed();
    }
    var progression: InputState = .CONTINUE;
    if (heldDebounce(raylib.KeyboardKey.down)) {
        input.shiftCursorLine(
            if (config.lines_reverse) -1 else 1,
            config.lines,
        );
    } else if (heldDebounce(raylib.KeyboardKey.up)) {
        input.shiftCursorLine(
            if (config.lines_reverse) 1 else -1,
            config.lines,
        );
    } else if (heldDebounce(raylib.KeyboardKey.left)) {
        input.shiftBufferCol(-1);
    } else if (heldDebounce(raylib.KeyboardKey.right)) {
        input.shiftBufferCol(1);
    } else if (!config.no_line_select and raylib.isKeyPressed(raylib.KeyboardKey.tab) and debounce(KEY_PRESS_DEBOUNCE_RATE_MS)) {
        try input.selectCursorLine();
        updated_buffer = true;
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.enter) and debounce(KEY_PRESS_DEBOUNCE_RATE_MS)) {
        progression = if (config.cyclic) .WRITE_CONTINUE else .WRITE_EXIT;
    } else if (raylib.isKeyPressed(raylib.KeyboardKey.escape) and debounce(KEY_PRESS_DEBOUNCE_RATE_MS)) {
        input.buffer.clearAndFree();
        input.buffer_col = 0;
        progression = .WRITE_EXIT;
    } else if (heldDebounce(raylib.KeyboardKey.backspace)) {
        if (input.buffer.items.len > 0) {
            _ = input.buffer.orderedRemove(input.buffer_col -| 1);
        }
        input.shiftBufferCol(-1);
        updated_buffer = true;
    }
    if (config.filter != null and updated_buffer) {
        try input.filterLines(config);
    }
    return progression;
}

