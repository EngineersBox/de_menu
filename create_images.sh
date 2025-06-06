#!/usr/bin/env bash

ZIG_VERSION=${1:-"0.14.1"}
ARCHS=(
    "arm64"
    "amd64"
)

for arch in "${ARCHS[@]}"; do
    docker build \
        -t "de_menu_linux_$arch:latest" \
        --platform "linux/$arch" \
        --build-arg="ZIG_VRESION=$ZIG_VERSION" \
        -f Dockerfile .
done
