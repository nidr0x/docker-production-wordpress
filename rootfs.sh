#!/bin/bash
set -ex

src_dir="/data"
dst_dir="/usr/src/wordpress"

if [ ! "$(ls -A $src_dir)" ]; then
    exit 0
fi

mkdir -p $dst_dir

for file in $src_dir/*; do
    filename=$(basename $file)
    if [ ! -L "$dst_dir/$filename" ] || [ "$(readlink "$dst_dir/$filename")" != "$file" ]; then
        ln -sf $file $dst_dir/$filename
    fi
done
