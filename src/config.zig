const std = @import("std");
const root = @import("root");
const known_folders = @import("known-folders");
// const microwave = @import("microwave");
const clap = @import("clap");
const raylib = @import("raylib");

const PATH_SEP: *const [1:0]u8 = std.fs.path.sep_str;
const CONFIG_PATH: []const u8 = PATH_SEP ++ "de_menu" ++ PATH_SEP ++ "config.toml";

const COLOURS: std.StaticStringMap(raylib.Color) = std.StaticStringMap(raylib.Color).initComptime(.{
    .{ "light_gray", raylib.Color.light_gray, },
    .{ "gray", raylib.Color.gray, },
    .{ "dark_gray", raylib.Color.dark_gray, },
    .{ "yellow", raylib.Color.yellow, },
    .{ "gold", raylib.Color.gold, },
    .{ "orange", raylib.Color.orange, },
    .{ "pink", raylib.Color.pink, },
    .{ "red", raylib.Color.red, },
    .{ "maroon", raylib.Color.maroon, },
    .{ "green", raylib.Color.green, },
    .{ "lime", raylib.Color.lime, },
    .{ "dark_green", raylib.Color.dark_green, },
    .{ "sky_blue", raylib.Color.sky_blue, },
    .{ "blue", raylib.Color.blue, },
    .{ "dark_blue", raylib.Color.dark_blue, },
    .{ "purple", raylib.Color.purple, },
    .{ "violet", raylib.Color.violet, },
    .{ "dark_purple", raylib.Color.dark_purple, },
    .{ "beige", raylib.Color.beige, },
    .{ "brown", raylib.Color.brown, },
    .{ "dark_brown", raylib.Color.dark_brown, },
    .{ "white", raylib.Color.white, },
    .{ "black", raylib.Color.black, },
    .{ "blank", raylib.Color.blank, },
    .{ "magenta", raylib.Color.magenta, },
    .{ "ray_white", raylib.Color.ray_white, },
});

fn colourParser(in: []const u8) std.fmt.ParseIntError!raylib.Color {
    const trimmed: []const u8 = std.mem.trimLeft(u8, in, "#");
    if (std.mem.indexOfAny(u8, trimmed, "0123456789") == null) blk: {
        return COLOURS.get(trimmed) orelse break :blk;
    }
    const hex: u32 = try clap.parsers.int(u32, 16)(trimmed);
    return raylib.getColor(hex);
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
};

pub const Config: type = struct {
    allocator: std.mem.Allocator,

    lines: usize = 20,
    monitor: ?usize = null,
    prompt: ?[]const u8 = null,

    font: ?[]const u8 = null,
    font_size: f32 = 20.0,
    font_spacing: f32 = 1.0,

    normal_bg: raylib.Color = raylib.Color.init(32, 31, 30, 0xFF),
    normal_fg: raylib.Color = raylib.Color.ray_white,
    selected_bg: raylib.Color = raylib.Color.dark_blue,
    selected_fg: raylib.Color = raylib.Color.ray_white,
    prompt_bg: raylib.Color = raylib.Color.dark_blue,
    prompt_fg: raylib.Color = raylib.Color.ray_white,

    pub fn initFromStdin(allocator: std.mem.Allocator) anyerror!?@This() {
        // TODO: Support all dmenu options
        const params = comptime clap.parseParamsComptime(
            \\ -h, --help
            \\ -l, --lines <usize>        lists items vertically, with the given number of lines
            \\ -m, --monitor <usize>      monitor to render to, leave unset to choose monitor that
            \\                            holds current focus
            \\ -p, --prompt <str>         defines the prompt to be displayed to the left of the input
            \\                            field, omitting this allows the input field and lines to
            \\                            extend fully to the left
            \\ -f, --font <str>           font to use, must be in a fontconfig discoverable location
            \\     --font_size <f32>      size of the font, defaults to 20.0
            \\     --font_spacing <f32>   spacing between characters of the font, defaults to 1.0
            \\     --normal_bg <colour>   normal background colour, name or hex string (#RRGGBBAA)
            \\     --normal_fg <colour>   normal foreground colour, name or hex string (#RRGGBBAA)
            \\     --selected_bg <colour> selected background colour, name or hex string (#RRGGBBAA)
            \\     --selected_fg <colour> selected foreground colour, name or hex string (#RRGGBBAA)
            \\     --prompt_bg <colour>   prompt background colour, name or hex string (#RRGGBBAA)
            \\     --prompt_fg <colour>   prompt foreground colour, name or hex string (#RRGGBBAA)
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
            try writer.writeAll("Usage: de_menu [options...]\nOptions:\n");
            try clap.help(
                writer,
                clap.Help,
                &params,
                .{},
            );
            return null;
        }
        var config: @This() = .{
            .allocator = allocator,
        };
        if (res.args.lines) |lines| {
            config.lines = lines;
        }
        if (res.args.monitor) |monitor| {
            config.monitor = monitor;
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
