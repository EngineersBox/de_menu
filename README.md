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
-c, --cyclic                    when the user presses enter on the buffer, it's contents
                                are written to stdout, the buffer is cleared and control
                                returns to the user, acting as a buffer cycle. This allows
                                the output of de_menu to be used elsewhere and then some
                                transformation of it to be piped back into stdin.
                                If escape is pressed, de_menu exits without printing to
                                stdout
    --no_line_select            disable the ability to fill the input buffer from a selected
                                line
-v, --version                   prints version information to stdout then exits
```

### Example

Using a simple script:

```bash
#!/usr/bin/env bash

echo "Selected: $(ls -t1 | zig-out/bin/de_menu -p Test)"
```

A menu appears, and with some typing into the input:

![de_menu window](./docs/example.png)

Traversing the list, and selecting the `build.zig` entry, and pressing enter then yields `Selected: build.zig` in stdout.

## Build and Run

Ensure you have raylib on your system and it is discoverable. Then just normal zig build shenanigans from there:

```bash
zig build
```

Run it:

```bash
./zig-out/bin/de_menu [options ...]
```

You can move the binary to wherever you want and it'll work fine.

## Known Issues

* Exceeding render boundary on text doesn't shift the visible text window yet.
* 1:1 compatibility with dmenu hasn't been achieved yet.

## Notes

I might port the manual rendering to use raygui instead to support stylesheets and all that good stuff. For now, features are more important, the current UI is good enough.

All the configuration for styling is emedded in the `src/renderer.zig` at the moment, at some stage it'll be configurable via CLI options and/or dotfiles. For the time being, modify those constants to change the look and feel of `de_menu`.
