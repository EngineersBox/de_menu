#!/usr/bin/env bash

zig build
ls -t1 | zig-out/bin/de_menu
