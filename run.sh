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
echo "Selected: $(ls -t1 | zig-out/bin/de_menu -l 5 \
                                               -p Test \
                                               -f Monocraft \
                                               --filter contains_insensitive \
                                               -a c,c \
                                               -w 800)"
