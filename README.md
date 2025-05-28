# de_menu
De dynamic menu, like dmenu, but new and shiny.

## Overview

You get a menu that can be typed into to filter the list items recieved from stdin.
List items are traversable with the up/down arrow keys and tab to saturate the input
with the hovered field. Pressing enter returns the selected item to stdout.

## Example

Using a simple script:

```bash
#!/usr/bin/env bash

echo "Selected: $(ls -t1 | zig-out/bin/de_menu -p Test)"
```

A menu appears, and with some typing into the input:

![de_menu window](./docs/example.png)

Traversing the list, and selecting the `build.zig` entry, and pressing enter then yields `Selected: build.zig` in stdout.
