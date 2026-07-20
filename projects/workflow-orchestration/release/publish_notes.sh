#!/usr/bin/env bash
# Side-effecting launcher for the //release:notes.publish target.
#
# Reads the already-built release artifacts from runfiles and copies them into
# a workspace-relative directory (out/published/). That directory is OUTSIDE
# Bazel's output boundary on purpose: bazel-out belongs to Bazel, but
# `bazel run :notes.publish` is the explicit, human-driven boundary crossing.

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

if [[ "$#" -lt 1 ]]; then
  echo "usage: bazel run //release:notes.publish" >&2
  echo "       (the launcher receives \$(rlocationpath ...) args from BUILD.bazel)" >&2
  exit 2
fi

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo "BUILD_WORKSPACE_DIRECTORY is not set." >&2
  echo "This launcher is meant to run via 'bazel run', which sets that variable." >&2
  exit 2
fi

publish_dir="${BUILD_WORKSPACE_DIRECTORY}/out/published"

# Idempotent re-run: scrub the previous publish output so a second invocation
# leaves the same tree on disk regardless of what the previous run wrote.
rm -rf "${publish_dir}"
mkdir -p "${publish_dir}"

for rlocation_arg in "$@"; do
  src="$(rlocation "${rlocation_arg}")"
  if [[ -z "${src}" || ! -f "${src}" ]]; then
    echo "could not resolve runfile ${rlocation_arg}" >&2
    exit 1
  fi
  cp "${src}" "${publish_dir}/$(basename "${src}")"
done

# Tiny manifest so a reader can verify which artifacts the publisher wrote
# without re-running Bazel.
manifest="${publish_dir}/PUBLISHED.txt"
{
  printf 'published_from=%s\n' "${BUILD_WORKSPACE_DIRECTORY}"
  printf 'artifacts:\n'
  for f in "${publish_dir}"/*; do
    [[ "${f}" == "${manifest}" ]] && continue
    printf '  - %s\n' "$(basename "${f}")"
  done
} > "${manifest}"

printf 'published %d artifact(s) to %s\n' "$#" "${publish_dir}"
