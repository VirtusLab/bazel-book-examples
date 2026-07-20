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

message_rlocation="$1"
message_path="$(rlocation "$message_rlocation")"

printf 'cwd=%s\n' "$PWD"
printf 'BUILD_WORKING_DIRECTORY=%s\n' "${BUILD_WORKING_DIRECTORY:-}"
printf 'BUILD_WORKSPACE_DIRECTORY=%s\n' "${BUILD_WORKSPACE_DIRECTORY:-}"
printf 'message_path=%s\n' "$message_path"
printf 'message=%s\n' "$(cat "$message_path")"

if [[ -f "./message.txt" ]]; then
  printf 'naive_relative=present\n'
else
  printf 'naive_relative=missing\n'
fi
