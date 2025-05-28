const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const Args = @import("args.zig").Args;
const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
const String = std.ArrayList(u8);
const UnicodeString = std.ArrayList(i32);

pub const Filter: type = fn (buffer: *const UnicodeString, line: *const String) bool;

pub const Filters: type = struct {
    pub fn stringContains(buffer: *const UnicodeString, line: *const String) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line.items) catch return false;
        return std.mem.containsAtLeast(
            i32,
            line_unicode,
            1,
            buffer.items,
        );
    }
};

pub const InputData: type = struct {
    allocator: std.mem.Allocator,
    lines: *ConcurrentArrayList(String),
    filtered_line_indices: std.ArrayList(usize),
    cursor_line: usize,
    buffer: UnicodeString,

    pub fn new(allocator: std.mem.Allocator, lines: *ConcurrentArrayList(String)) @This() {
        return @This(){
            .allocator = allocator,
            .lines = lines,
            .filtered_line_indices = std.ArrayList(usize).init(allocator),
            .cursor_line = 0,
            .buffer = UnicodeString.init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.buffer.deinit();
        self.filtered_line_indices.deinit();
    }

    pub fn selectCursorLine(self: *@This()) anyerror!void {
        self.buffer.clearAndFree();
        std.debug.assert(self.cursor_line < self.lines.count());
        const line: *const String = &self.lines.get(self.cursor_line);
        const codepoints: []i32 = try raylib.loadCodepoints(line.items);
        try self.buffer.appendSlice(codepoints);
        raylib.unloadCodepoints(codepoints);
    }

    pub fn shiftCursorLine(self: *@This(), shift: isize) void {
        const next: usize = @intCast(@max(0, @as(isize, @intCast(self.cursor_line)) + shift));
        self.cursor_line = @min(next, self.lines.count() -| 1);
    }

    pub fn filterLines(self: *@This(), filter: Filter) !void {
        // Lines are filtered only when there is text in the buffer
        if (self.buffer.items.len == 0) {
            return;
        }
        self.filtered_line_indices.clearAndFree();
        self.lines.rwlock.lockShared();
        defer self.lines.rwlock.unlockShared();
        for (self.lines.array_list.items, 0..) |*line, i| {
            if (filter(&self.buffer, line)) {
                try self.filtered_line_indices.append(i);
            }
        }
        self.cursor_line = @min(self.cursor_line, self.filtered_line_indices.items.len -| 1);
    }

};
