#!/bin/sh

set -eu

dockerfile="${1:-Dockerfile}"

matches="$(grep -En '^ENV[[:space:]]+WP_VERSION=[^[:space:]]+$' "$dockerfile" || true)"
count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"

if [ "$count" -ne 1 ]; then
  echo "Expected exactly one ENV WP_VERSION=... line in $dockerfile, found $count." >&2
  exit 1
fi

printf '%s\n' "$matches" | sed -E 's/^[0-9]+:ENV[[:space:]]+WP_VERSION=([^[:space:]]+)$/\1/'
