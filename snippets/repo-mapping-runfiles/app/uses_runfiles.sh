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

# $1 is the rlocationpath token Bazel substituted at analysis time.
# It is the runfiles-relative apparent-name path, e.g. `aux_data/value.txt`
# under Bzlmod (or `aux_data~/value.txt` style canonical names depending on
# the Bazel version). The runfiles library resolves whichever spelling is
# correct on this host, so the script never has to know.
value_rlocation="$1"
value_path="$(rlocation "$value_rlocation")"

if [[ -z "${value_path:-}" || ! -f "$value_path" ]]; then
  echo >&2 "ERROR: rlocation could not resolve '${value_rlocation}'"
  exit 1
fi

printf 'rlocationpath=%s\n' "$value_rlocation"
printf 'resolved_path=%s\n' "$value_path"
printf 'payload=%s\n' "$(cat "$value_path")"
