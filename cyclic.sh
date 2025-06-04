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

function filter() {
    tee grep -vE "^>" | xargs printf "%s"
}

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
    | grep --line-buffered -vE "^>" 1>$PIPE
# NOTE: By default grep waits for a page (4KiB or 8iKB)
#       instead of per line. Using `--line-buffered` will 
#       tell it to buffer per-line instead (i.e. ending
#       with a \n or \r depending on platform)
