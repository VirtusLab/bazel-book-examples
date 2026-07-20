#!/usr/bin/env bash
set -euo pipefail

artifact="$1"
expected="${EXPECTED_VALUE:-unset}"
actual="$(cat "$artifact")"

if [[ "$actual" != "$expected" ]]; then
  printf 'env mismatch: expected %q, got %q\n' "$expected" "$actual" >&2
  exit 1
fi

printf 'ok: print_env produced %q\n' "$actual"
