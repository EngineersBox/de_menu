const std = @import("std");
const raylib = @import("raylib");
const ZgLetterCasing = @import("zg_letter_casing");

const ConcurrentArrayList = @import("containers/concurrent_array_list.zig").ConcurrentArrayList;
pub const CString = [:0]const u8;
pub const UnicodeString = std.ArrayList(i32);

pub const Filter: type = *const fn (
    allocator: std.mem.Allocator,
    zg_letter_casing: *const ZgLetterCasing,
    buffer: *const UnicodeString,
    line: CString,
) bool;

pub const Filters: type = struct {
    pub fn containsInsensitive(
        allocator: std.mem.Allocator,
        zg_letter_casing: *const ZgLetterCasing,
        buffer: *const UnicodeString,
        line: CString,
    ) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line) catch return false;
        defer raylib.unloadCodepoints(line_unicode);
        const line_lower: []const u8 = ZgLetterCasing.toLowerStr(
            zg_letter_casing.*,
            allocator,
            @alignCast(@ptrCast(line_unicode[0..line.len])),
        ) catch return false;
        defer allocator.free(line_lower);
        const buffer_lower: []const u8 = ZgLetterCasing.toLowerStr(
            zg_letter_casing.*,
            allocator,
            @alignCast(@ptrCast(buffer.items)),
        ) catch return false;
        defer allocator.free(buffer_lower);
        return std.mem.containsAtLeast(
            u8,
            line_lower,
            1,
            buffer_lower,
        );
    }
    pub fn contains(
        _: std.mem.Allocator,
        _: *const ZgLetterCasing,
        buffer: *const UnicodeString,
        line: CString,
    ) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line) catch return false;
        defer raylib.unloadCodepoints(line_unicode);
        return std.mem.containsAtLeast(
            i32,
            line_unicode[0..line.len],
            1,
            buffer.items,
        );
    }
    pub fn startsWith(
        _: std.mem.Allocator,
        _: *const ZgLetterCasing,
        buffer: *const UnicodeString,
        line: CString,
    ) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line) catch return false;
        defer raylib.unloadCodepoints(line_unicode);
        return std.mem.startsWith(
            i32,
            line_unicode[0..line.len],
            buffer.items,
        );
    }
    pub fn startsWithInsensitive(
        allocator: std.mem.Allocator,
        zg_letter_casing: *const ZgLetterCasing,
        buffer: *const UnicodeString,
        line: CString,
    ) bool {
        const line_unicode: []i32 = raylib.loadCodepoints(line) catch return false;
        defer raylib.unloadCodepoints(line_unicode);
        const line_lower: []const u8 = ZgLetterCasing.toLowerStr(
            zg_letter_casing.*,
            allocator,
            @alignCast(@ptrCast(line_unicode[0..line.len])),
        ) catch return false;
        defer allocator.free(line_lower);
        const buffer_lower: []const u8 = ZgLetterCasing.toLowerStr(
            zg_letter_casing.*,
            allocator,
            @alignCast(@ptrCast(buffer.items)),
        ) catch return false;
        defer allocator.free(buffer_lower);
        return std.mem.startsWith(
            u8,
            line_lower,
            buffer_lower,
        );
    }
};

pub const FILTERS: std.StaticStringMap(Filter) = std.StaticStringMap(Filter).initComptime(.{
    .{
        "contains",
        Filters.contains,
    },
    .{
        "contains_insensitive",
        Filters.containsInsensitive,
    },
    .{
        "starts_with",
        Filters.startsWith,
    },
    .{
        "starts_with_insensitive",
        Filters.startsWithInsensitive,
    },
});
