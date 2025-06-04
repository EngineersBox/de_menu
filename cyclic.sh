#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber -o nounset

PWD="$(pwd)"
PROJECT_DIR_NAME="de_menu"

case "$(basename "$PWD")" in
  "$PROJECT_DIR_NAME") ;;
  *)
    echo "[ERROR] This script must be run from the $PROJECT_DIR_NAME directory, not $PWD"
    exit 1
    ;;
esac

zig build -Doptimize=Debug --release=safe

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
           --set="vspace off" 1>$PIPE
# FIXME: Figure out why piping the result of qalc
#        via grep -vE "^>" strips all output, but
#        when done as a standalone script it works
#        just fine:
#        echo "1 + 2" | qalc -c=0 -s="vspace off" | grep -vE "^>"
