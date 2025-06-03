#!/usr/bin/env bash

zig build

PIPE=/tmp/__de_menu_cyclic_pipe

rm -f $PIPE
mkfifo $PIPE
./zig-out/bin/de_menu -l 5 --lines_reverse \
                      -f Monocraft \
                      -p "Expression:" \
                      --no_line_select \
                      --filter "none" \
                      --cyclic 0<$PIPE \
    | qalc -u8 \
           --color=0 \
           --set="mulsign 0" \
           --set="divsign 0" \
           --set="uni off" \
           --set="uniexp 0" \
           --set="vspace off" \
    1>$PIPE
