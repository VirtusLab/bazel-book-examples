#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
validation_root="$(mktemp -d "${TMPDIR:-/tmp}/glyph-checkpoints.XXXXXX")"
trap 'rm -rf "$validation_root"' EXIT

for checkpoint in 1 2 3; do
  checkpoint_root="$validation_root/checkpoint${checkpoint}"
  bash "$project_root/checkpoints/materialize_checkpoint.sh" "$checkpoint" "$checkpoint_root" >/dev/null
  (
    cd "$checkpoint_root"
    bazel --output_base="$validation_root/output-checkpoint${checkpoint}" build //examples/basic:bootstrap
  )
done

checkpoint3_visibility_log="$validation_root/checkpoint3-visibility.log"
if (
  cd "$validation_root/checkpoint3"
  bazel --output_base="$validation_root/output-checkpoint3" build //consumer:illegal_internal_load
) >"$checkpoint3_visibility_log" 2>&1; then
  echo "checkpoint 3 unexpectedly allowed //consumer to load //glyph/internal:rules.bzl" >&2
  exit 1
fi

if ! grep -Fq "is not visible for loading from package //consumer" "$checkpoint3_visibility_log"; then
  echo "checkpoint 3 failed for a reason other than the expected load visibility boundary" >&2
  cat "$checkpoint3_visibility_log" >&2
  exit 1
fi

echo "validated mini-ruleset checkpoints 1, 2, and 3"
echo "validated checkpoint 3 public facade and rejected external internal-rule load"
