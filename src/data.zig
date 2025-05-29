const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);
const UnicodeString = std.ArrayList(i32);

pub const Filter: type = fn (buffer: *const UnicodeString, line: *const String) bool;

pub const Filters: type = struct {
    pub fn contains(buffer: *const UnicodeString, line: *const String) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line.items) catch return false;
        defer raylib.unloadCodepoints(line_unicode);
        return std.mem.containsAtLeast(
            i32,
            line_unicode[0..line.items.len],
            1,
            buffer.items,
        );
    }
    pub fn startsWith(buffer: *const UnicodeString, line: *const String) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line.items) catch return false;
        defer raylib.unloadCodepoints(line_unicode);
        return std.mem.startsWith(
            i32,
            line_unicode[0..line.items.len],
            buffer.items,
        );
    }
};

pub const InputData: type = struct {
    allocator: std.mem.Allocator,
    lines: ConcurrentArrayList(String),
    rendered_lines_start: usize,
    filtered_line_indices: std.ArrayList(usize),
    cursor_line: ?usize,
    buffer_col: usize,
    buffer: UnicodeString,

    pub fn new(allocator: std.mem.Allocator) @This() {
        return @This(){
            .allocator = allocator,
            .lines = ConcurrentArrayList(String).init(allocator),
            .rendered_lines_start = 0,
            .filtered_line_indices = std.ArrayList(usize).init(allocator),
            .cursor_line = 0,
            .buffer_col = 0,
            .buffer = UnicodeString.init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.lines.rwlock.lock();
        for (self.lines.array_list.items) |*line| {
            line.*.deinit();
        }
        self.lines.rwlock.unlock();
        self.lines.deinit();
        self.filtered_line_indices.deinit();
        self.buffer.deinit();
    }

    pub fn selectCursorLine(self: *@This()) anyerror!void {
        const filtered = self.buffer.items.len != 0;
        self.buffer.clearAndFree();
        var cursor_line: usize = self.cursor_line orelse return;
        if (filtered) {
            cursor_line = self.filtered_line_indices.items[cursor_line];
        }
        const line: *const String = &self.lines.get(cursor_line);
        // Filtered have changed, so previous cursor line is invalid
        self.cursor_line = 0;
        // Convert to unicode
        const codepoints: []i32 = try raylib.loadCodepoints(line.items);
        defer raylib.unloadCodepoints(codepoints);
        try self.buffer.appendSlice(codepoints[0..line.items.len]);
        // Put blinking cursor at the end of the buffer
        self.buffer_col = line.items.len;
    }

    pub fn shiftCursorLine(self: *@This(), shift: isize, lines_window_size: usize) void {
        const cursor_line: isize = @intCast(self.cursor_line orelse 0);
        const line_count: usize = if (self.buffer.items.len == 0)
            // Not filtered
            self.lines.count()
        else
            // Filtered
            self.filtered_line_indices.items.len;
        if (line_count == 0) {
            self.cursor_line = null;
            return;
        }
        self.cursor_line = @min(line_count -| 1, @as(usize, @intCast(@max(0, cursor_line + shift))));
        if (self.cursor_line.? < self.rendered_lines_start) {
            self.rendered_lines_start -|= 1;
        } else if (self.cursor_line.? >= self.rendered_lines_start + lines_window_size) {
            self.rendered_lines_start = @min(
                self.rendered_lines_start + 1,
                line_count,
            );
        }
    }

    pub fn shiftBufferCol(self: *@This(), shift: isize) void {
        const buffer_col: isize = @intCast(self.buffer_col);
        self.buffer_col = @intCast(@max(
            0,
            @min(
                buffer_col + shift,
                @as(isize, @intCast(self.buffer.items.len)),
            ),
        ));
    }

    pub fn filterLines(self: *@This(), filter: Filter) !void {
        // Lines are filtered only when there is text in the buffer
        if (self.buffer.items.len == 0) {
            // Using size of 1 here just ensures
            // we set the default rendered_lines_start
            self.shiftCursorLine(0, 1);
            return;
        }
        self.cursor_line = 0;
        self.rendered_lines_start = 0;
        self.filtered_line_indices.clearAndFree();
        self.lines.rwlock.lockShared();
        defer self.lines.rwlock.unlockShared();
        for (self.lines.array_list.items, 0..) |*line, i| {
            if (filter(&self.buffer, line)) {
                try self.filtered_line_indices.append(i);
            }
        }
        self.shiftCursorLine(0, 1);
    }
};
