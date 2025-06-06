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

OPTIMISE=${1:-"ReleaseFast"}
RELEASE=${2:-"fast"}

OUT_DIR="zig-out/bin"

# Linux x86-64
docker run -it \
    -v "./:/opt/de_menu" \
    -w "/opt/de_menu" \
    --rm \
    de_menu_linux_amd64:latest \
    zig build -Doptimize="$OPTIMISE" --release="$RELEASE"
mv "$OUT_DIR/de_menu" "$OUT_DIR/de_menu-x86_64-linux"
echo "[INFO] Created $OUT_DIR/de_menu-x86_64-linux"

# Linux ARM64
docker run -it \
    -v "./:/opt/de_menu" \
    -w "/opt/de_menu" \
    --rm \
    de_menu_linux_arm64:latest \
    zig build -Doptimize="$OPTIMISE" --release="$RELEASE"
mv "$OUT_DIR/de_menu" "$OUT_DIR/de_menu-aarch64-linux"
echo "[INFO] Created $OUT_DIR/de_menu-aarch64-linux"

function build_and_move() {
    local target="$1"
    zig build \
        -Dtarget="$target" \
        -Doptimize="$OPTIMISE" \
        --release="$RELEASE"
    for extension in "${@:2}"; do
        mv "$OUT_DIR/de_menu$extension" "$OUT_DIR/de_menu-$target$extension"
        echo "[INFO] Created $OUT_DIR/de_menu-$target$extension"
    done
}
#
build_and_move "x86_64-macos" ""
build_and_move "aarch64-macos" ""
build_and_move "x86_64-windows" ".exe" ".pdb"
build_and_move "aarch64-windows" ".exe" ".pdb"
