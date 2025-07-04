# de_menu

De dynamic menu, like dmenu, but new and shiny. Built to serve my usages, avoiding the need for X11/xQuartz and a reason to use Raylib.

## Overview

You get a menu that can be typed into to filter the list items recieved from stdin.
List items are traversable with the up/down arrow keys and tab to saturate the input
with the hovered field. Pressing enter returns the selected item to stdout.

### Options

```
-h, --help                      prints this help text to stdout then exits
-l, --lines <usize>             lists items vertically, with the given number of lines
    --lines_reverse             render the lines in reverse order
-w, --width <usize>             total width of the menu, inclusive of prompt if present
                                (overrides -b, -t flag width)
-x, --pos_x <usize>             screen x position (top left of menu), overrides -a flag
                                x alignment
-y, --pos_y <usize>             screen y position (top left of menu), overrides -a flag
                                y alignment
-a, --alignment <alignment>     comma separated pair of positions for x (t = top, c = centre,
                                b = bottom) and then y (r = right, c = centre, b = bottom)
                                alignment. These are overridden by -w, -x, -y flags.
                                Without the -w flag, this will use the whole screen width,
                                making the h component redundant. With the -w flag, both
                                the x and y components function as general alignment.
-m, --monitor <usize>           monitor to render to, leave unset to choose monitor that
                                holds current focus
-p, --prompt <str>              defines the prompt to be displayed to the left of the input
                                field, omitting this allows the input field and lines to
                                extend fully to the left
-f, --font <str>                font to use, must be in a fontconfig discoverable location
    --font_size <f32>           size of the font, defaults to 20.0
    --font_spacing <f32>        spacing between characters of the font, defaults to 1.0
    --normal_bg <colour>        normal background colour, name or hex string (#RRGGBBAA)
    --normal_fg <colour>        normal foreground colour, name or hex string (#RRGGBBAA)
    --selected_bg <colour>      selected background colour, name or hex string (#RRGGBBAA)
    --selected_fg <colour>      selected foreground colour, name or hex string (#RRGGBBAA)
    --prompt_bg <colour>        prompt background colour, name or hex string (#RRGGBBAA)
    --prompt_fg <colour>        prompt foreground colour, name or hex string (#RRGGBBAA)
    --filter <filter>           type of filter to use when filtering lines based on user
                                input, Must be one of "contains", "starts_with",
                                "contains_insensitive", "starts_with_insensitive" or "none"
    --prompt_text_offset <f32>  offset from the left side of the prompt text background
    --prompt_text_padding <f32> offset from top and bottom of the prompt text background
    --line_text_offset <f32>    offset from the left side of the line text background
    --line_text_padding <f32>   offset from top and bottom of the line text background
-c, --cyclic                    causes shift-return to print the input buffer instead of the
                                selected line to stdout and then continues instead of exiting
    --no_line_select            disable the ability to fill the input buffer from a selected
                                line
-v, --version                   prints version information to stdout then exits
```

### Key Bindings

```
Tab
       Copy the selected item to the input field

Return
       Confirm selection. Prints the selected item to stdout and exits, returning success.
       If the `cyclic` flag is used, then this prints the input text to stdout and continues instead.

Ctrl-Return
       Confirm selection. Prints the selected item to stdout and continues

Shift-Return
       Confirm selection. Prints the input text to stdout and exits, returning success
```

## Installation

There are pre-build binaries provided as releases, they can be downloaded into a discoverable location (i.e in a `PATH` location on UNIX systems).

## Build and Run

If you prefer to build it yourself, or there is no pre-built binary for your specific system then this will do exactly that.

Ensure you have raylib on your system and it is discoverable. Then just normal zig build shenanigans from there, note that the
`INSTALL DIR` should omit the `bin/` sub-directory (i.e. `/usr/local`).

```bash
zig build install -p <INSTALL DIR>
```

Run it:

```bash
de_menu [options ...]
```

You can move the binary to wherever you want and it'll work fine.

## Examples

There are two examples, in this repo:

1. `run.sh`: displays the project directory contents, allowing selection with enter to print to stdout
2. `cyclic.sh`: sends expressions the user types to `qalc` and uses named pipes to send the result
    back into the input of `de_menu` to show as history

### `run.sh`

![Listing Directory](./docs/example_listing_dir)

### `cyclic.sh`

![Cyclic Pipe Through Qalc](./docs/example_qalc_cyclic)

## Known Issues

* Exceeding render boundary on text doesn't shift the visible text window yet.
* 1:1 compatibility with dmenu hasn't been achieved yet.

## Notes

I might port the manual rendering to use raygui instead to support stylesheets and all that good stuff. For now, features are more important, the current UI is good enough.
