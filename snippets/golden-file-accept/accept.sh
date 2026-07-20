#!/usr/bin/env bash
set -euo pipefail

# --- begin runfiles.bash initialization v3 ---
set +e
f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }
set -e
# --- end runfiles.bash initialization v3 ---

actual_rlocation="$1"
golden_relative="$2"
actual_path="$(rlocation "$actual_rlocation")"

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "BUILD_WORKSPACE_DIRECTORY is not set" >&2
  exit 1
fi

golden_path="${BUILD_WORKSPACE_DIRECTORY}/${golden_relative}"

if cmp -s "$actual_path" "$golden_path"; then
  printf 'golden already up to date: %s\n' "$golden_relative"
  exit 0
fi

cp "$actual_path" "$golden_path"
printf 'updated golden: %s\n' "$golden_relative"
