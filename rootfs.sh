#!/bin/sh
set -eu

src_dir="/data"
dst_dir="/usr/src/wordpress"

if [ ! -d "$src_dir" ]; then
    exit 0
fi

if [ -z "$(find "$src_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    exit 0
fi

mkdir -p "$dst_dir"

for file in "$src_dir"/*; do
    filename=$(basename "$file")
    if [ ! -L "$dst_dir/$filename" ] || [ "$(readlink "$dst_dir/$filename")" != "$file" ]; then
        ln -sf "$file" "$dst_dir/$filename"
    fi
done
