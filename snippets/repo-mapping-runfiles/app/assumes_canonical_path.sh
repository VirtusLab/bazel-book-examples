#!/usr/bin/env bash
set -euo pipefail

# --- ANTI-PATTERN: do not copy this into real code. ---
#
# This script demonstrates a runtime data-lookup style that worked in
# WORKSPACE-mode-like layouts where the apparent repo name happened to equal
# the directory under `external/`. Under Bzlmod, repositories are placed under
# their *canonical* name (something like `aux_data~`, `_main~aux_extension~aux_data`,
# or whatever future scheme Bazel chooses). Canonical names are explicitly
# documented as not-an-API and may change between Bazel versions.
#
# So even if a reference like the one below resolves on one machine today,
# it will silently break on:
#   - a different Bazel version with a different canonical-name format
#   - a different module graph that re-canonicalizes the same apparent name
#   - any consumer that tries to runfiles-resolve this script in isolation
#
# We deliberately do NOT touch the filesystem here. The point is the warning,
# not the read. That keeps this script reproducible (exit 0) under the snippet
# command list while still documenting the failure mode for readers.

guess="external/aux_data/value.txt"

cat <<EOF
[anti-pattern] hard-coded path: ${guess}
[anti-pattern] this assumes apparent repo name 'aux_data' == on-disk directory.
[anti-pattern] under Bzlmod the directory is the *canonical* name and is not stable.
[anti-pattern] use \$(rlocationpath @aux_data//:value.txt) + a runfiles library instead.
EOF
