const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const clap = @import("clap");
const raylib = @import("raylib");

const Filter = @import("data.zig").Filter;
const Filters = @import("data.zig").Filters;
const FILTERS = @import("data.zig").FILTERS;
const meta = @import("meta.zig");

const PATH_SEP: *const [1:0]u8 = std.fs.path.sep_str;
const CONFIG_PATH: []const u8 = PATH_SEP ++ "de_menu" ++ PATH_SEP ++ "config.toml";

const COLOURS: std.StaticStringMap(raylib.Color) = std.StaticStringMap(raylib.Color).initComptime(.{
    .{ "light_gray", raylib.Color.light_gray },
    .{ "gray", raylib.Color.gray },
    .{ "dark_gray", raylib.Color.dark_gray },
    .{ "yellow", raylib.Color.yellow },
    .{ "gold", raylib.Color.gold },
    .{ "orange", raylib.Color.orange },
    .{ "pink", raylib.Color.pink },
    .{ "red", raylib.Color.red },
    .{ "maroon", raylib.Color.maroon },
    .{ "green", raylib.Color.green },
    .{ "lime", raylib.Color.lime },
    .{ "dark_green", raylib.Color.dark_green },
    .{ "sky_blue", raylib.Color.sky_blue },
    .{ "blue", raylib.Color.blue },
    .{ "dark_blue", raylib.Color.dark_blue },
    .{ "purple", raylib.Color.purple },
    .{ "violet", raylib.Color.violet },
    .{ "dark_purple", raylib.Color.dark_purple },
    .{ "beige", raylib.Color.beige },
    .{ "brown", raylib.Color.brown },
    .{ "dark_brown", raylib.Color.dark_brown },
    .{ "white", raylib.Color.white },
    .{ "black", raylib.Color.black },
    .{ "blank", raylib.Color.blank },
    .{ "magenta", raylib.Color.magenta },
    .{ "ray_white", raylib.Color.ray_white },
});

fn colourParser(in: []const u8) std.fmt.ParseIntError!raylib.Color {
    const trimmed: []const u8 = std.mem.trimLeft(u8, in, "#");
    if (std.mem.indexOfAny(u8, trimmed, "0123456789") == null) blk: {
        return COLOURS.get(trimmed) orelse break :blk;
    }
    const hex: u32 = try clap.parsers.int(u32, 16)(trimmed);
    return raylib.getColor(hex);
}

fn filterParser(in: []const u8) error{InvalidFilter}!Filter {
    return FILTERS.get(in) orelse error.InvalidFilter;
}

fn alignmentParser(in: []const u8) error{InvalidAlignment}!Alignment {
    if (in.len != 3) {
        return error.InvalidAlignment;
    }
    const x: AlignmentX = switch (in[0]) {
        'l' => AlignmentX.LEFT,
        'c' => AlignmentX.CENTRE,
        'r' => AlignmentX.RIGHT,
        else => return error.InvalidAlignment,
    };
    const y: AlignmentY = switch (in[2]) {
        't' => AlignmentY.TOP,
        'c' => AlignmentY.CENTRE,
        'b' => AlignmentY.BOTTOM,
        else => return error.InvalidAlignment,
    };
    return Alignment.init(x, y);
}

const PARSERS = .{
    .string = clap.parsers.string,
    .str = clap.parsers.string,
    .u8 = clap.parsers.int(u8, 0),
    .u16 = clap.parsers.int(u16, 0),
    .u32 = clap.parsers.int(u32, 0),
    .u64 = clap.parsers.int(u64, 0),
    .usize = clap.parsers.int(usize, 0),
    .i8 = clap.parsers.int(i8, 0),
    .i16 = clap.parsers.int(i16, 0),
    .i32 = clap.parsers.int(i32, 0),
    .i64 = clap.parsers.int(i64, 0),
    .isize = clap.parsers.int(isize, 0),
    .f32 = clap.parsers.float(f32),
    .f64 = clap.parsers.float(f64),
    .colour = colourParser,
    .filter = filterParser,
    .alignment = alignmentParser,
};

pub const AlignmentY: type = enum {
    BOTTOM,
    CENTRE,
    TOP,
};

pub const AlignmentX: type = enum {
    LEFT,
    CENTRE,
    RIGHT,
};

pub const Alignment: type = struct {
    x: AlignmentX = .CENTRE,
    y: AlignmentY = .CENTRE,

    pub fn init(x: AlignmentX, y: AlignmentY) @This() {
        return @This() {
            .x = x,
            .y = y,
        };
    }
};

pub const Config: type = struct {
    allocator: std.mem.Allocator,

    lines: usize = 20,

    width: ?i32 = null,
    pos_x: ?i32 = null,
    pos_y: ?i32 = null,
    alignment: ?Alignment = null,

    monitor: ?i32 = null,
    prompt: ?[]const u8 = null,

    line_text_offset: f32 = 10.0,
    line_text_padding: f32 = 1.0,
    prompt_text_offset: f32 = 10.0,
    prompt_text_padding: f32 = 1.0,

    font: ?[]const u8 = null,
    font_size: f32 = 20.0,
    font_spacing: f32 = 1.0,

    normal_bg: raylib.Color = raylib.Color.init(32, 31, 30, 0xFF),
    normal_fg: raylib.Color = raylib.Color.ray_white,
    selected_bg: raylib.Color = raylib.Color.dark_blue,
    selected_fg: raylib.Color = raylib.Color.ray_white,
    prompt_bg: raylib.Color = raylib.Color.dark_blue,
    prompt_fg: raylib.Color = raylib.Color.ray_white,

    filter: Filter = Filters.contains,

    pub fn initFromStdin(allocator: std.mem.Allocator) anyerror!?@This() {
        // NOTE: Should we support case-insensitivity by -i flag,
        //       or just a filter type? For some filters it might
        //       not make sense to have a general insensitivity
        //       flag, so maybe not.
        const params = comptime clap.parseParamsComptime(
            \\ -h, --help                      prints this help text to stdout then exits
            \\ -l, --lines <usize>             lists items vertically, with the given number of lines
            \\ -w, --width <usize>             total width of the menu, inclusive of prompt if present
            \\                                 (overrides -b, -t flag width)
            \\ -x, --pos_x <usize>             screen x position (top left of menu), overrides -a flag
            \\                                 x alignment
            \\ -y, --pos_y <usize>             screen y position (top left of menu), overrides -a flag
            \\                                 y alignment
            \\ -a, --alignment <alignment>     comma separated pair of positions for x (t = top, c = centre,
            \\                                 b = bottom) and then y (r = right, c = centre, b = bottom)
            \\                                 alignment. These are overridden by -w, -x, -y flags.
            \\                                 Without the -w flag, this will use the whole screen width,
            \\                                 making the h component redundant. With the -w flag, both
            \\                                 the x and y components function as general alignment.
            \\ -m, --monitor <usize>           monitor to render to, leave unset to choose monitor that
            \\                                 holds current focus
            \\ -p, --prompt <str>              defines the prompt to be displayed to the left of the input
            \\                                 field, omitting this allows the input field and lines to
            \\                                 extend fully to the left
            \\ -f, --font <str>                font to use, must be in a fontconfig discoverable location
            \\     --font_size <f32>           size of the font, defaults to 20.0
            \\     --font_spacing <f32>        spacing between characters of the font, defaults to 1.0
            \\     --normal_bg <colour>        normal background colour, name or hex string (#RRGGBBAA)
            \\     --normal_fg <colour>        normal foreground colour, name or hex string (#RRGGBBAA)
            \\     --selected_bg <colour>      selected background colour, name or hex string (#RRGGBBAA)
            \\     --selected_fg <colour>      selected foreground colour, name or hex string (#RRGGBBAA)
            \\     --prompt_bg <colour>        prompt background colour, name or hex string (#RRGGBBAA)
            \\     --prompt_fg <colour>        prompt foreground colour, name or hex string (#RRGGBBAA)
            \\     --filter <filter>           type of filter to use when filtering lines based on user
            \\                                 input, Must be one of: "conatins", "starts_with"
            \\     --prompt_text_offset <f32>  offset from the left side of the prompt text background
            \\     --prompt_text_padding <f32> offset from top and bottom of the prompt text background
            \\     --line_text_offset <f32>    offset from the left side of the line text background
            \\     --line_text_padding <f32>   offset from top and bottom of the line text background
            \\ -v, --version                   prints version information to stdout then exits
        );
        var diag = clap.Diagnostic{};
        var res = clap.parse(
            clap.Help,
            &params,
            PARSERS,
            .{
                .diagnostic = &diag,
                .allocator = allocator,
            },
        ) catch |err| {
            // Report useful error and exit.
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
        };
        defer res.deinit();
        if (res.args.help != 0) {
            var writer = std.io.getStdErr().writer();
            try writer.writeAll("Usage: " ++ meta.NAME ++ " [options...]\nOptions:\n");
            try clap.help(
                writer,
                clap.Help,
                &params,
                .{},
            );
            return null;
        } else if (res.args.version != 0) {
            var writer = std.io.getStdErr().writer();
            try writer.writeAll(
                meta.NAME
                ++ " version " ++ meta.VERSION 
                ++ " compiled on " ++ meta.COMPILATION_DATE
                ++ "\n"
            );
            return null;
        }
        var config: @This() = .{
            .allocator = allocator,
        };
        if (res.args.lines) |lines| {
            config.lines = lines;
        }
        if (res.args.width) |width| {
            config.width = @intCast(width);
        }
        if (res.args.pos_x) |pos_x| {
            config.pos_x = @intCast(pos_x);
        }
        if (res.args.pos_y) |pos_y| {
            config.pos_y = @intCast(pos_y);
        }
        if (res.args.alignment) |alignment| {
            config.alignment = alignment;
        }
        if (res.args.monitor) |monitor| {
            config.monitor = @intCast(monitor);
        }
        if (res.args.prompt) |prompt| {
            config.prompt = try allocator.dupe(u8, prompt);
        }
        if (res.args.font) |font| {
            config.font = try allocator.dupe(u8, font);
        }
        if (res.args.font_size) |font_size| {
            config.font_size = font_size;
        }
        if (res.args.font_spacing) |font_spacing| {
            config.font_spacing = font_spacing;
        }
        if (res.args.normal_bg) |normal_bg| {
            config.normal_bg = normal_bg;
        }
        if (res.args.normal_fg) |normal_fg| {
            config.normal_fg = normal_fg;
        }
        if (res.args.selected_bg) |selected_bg| {
            config.selected_bg = selected_bg;
        }
        if (res.args.selected_fg) |selected_fg| {
            config.selected_fg = selected_fg;
        }
        if (res.args.prompt_bg) |prompt_bg| {
            config.prompt_bg = prompt_bg;
        }
        if (res.args.prompt_fg) |prompt_fg| {
            config.prompt_fg = prompt_fg;
        }
        if (res.args.prompt_text_offset) |prompt_text_offset| {
            config.prompt_text_offset = prompt_text_offset;
        }
        if (res.args.prompt_text_padding) |prompt_text_padding| {
            config.prompt_text_padding = prompt_text_padding;
        }
        if (res.args.line_text_offset) |line_text_offset| {
            config.line_text_offset = line_text_offset;
        }
        if (res.args.line_text_padding) |line_text_padding| {
            config.line_text_padding = line_text_padding;
        }
        if (res.args.filter) |filter| {
            config.filter = filter;
        }
        return config;
    }

    pub fn deinit(self: *@This()) void {
        if (self.prompt) |prompt| {
            self.allocator.free(prompt);
        }
        if (self.font) |font| {
            self.allocator.free(font);
        }
    }
};
