#!/usr/bin/env bash
set -euo pipefail

actual="$1"
golden="$2"

if cmp -s "$actual" "$golden"; then
  printf 'golden matches: %s\n' "$golden"
  exit 0
fi

printf 'golden drift detected: %s\n' "$golden" >&2
diff -u "$golden" "$actual"
