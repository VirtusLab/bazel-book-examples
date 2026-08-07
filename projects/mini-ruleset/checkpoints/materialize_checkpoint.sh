#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || ! "$1" =~ ^[123]$ ]]; then
  echo "usage: bash checkpoints/materialize_checkpoint.sh <1|2|3> <empty-destination>" >&2
  exit 2
fi

checkpoint="$1"
destination="$2"
project_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -e "$destination" ]]; then
  echo "destination already exists: $destination" >&2
  exit 2
fi

mkdir -p "$destination"
(
  cd "$project_root"
  tar \
    --exclude='./bazel-*' \
    --exclude='./MODULE.bazel.lock' \
    --exclude='./checkpoints/overlays' \
    -cf - .
) | (
  cd "$destination"
  tar -xf -
)

for overlay_checkpoint in $(seq 1 "$checkpoint"); do
  cp -R "$project_root/checkpoints/overlays/checkpoint${overlay_checkpoint}/." "$destination/"
done

echo "$destination"
