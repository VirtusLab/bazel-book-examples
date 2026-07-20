#!/usr/bin/env bash
set -euo pipefail

cat <<'PLAN'
# Formatting gate for BUILD maintenance.
# This example validates a tiny local style check; production repos usually add
# buildifier as a pinned tool or CI image dependency.

buildifier -r .
bazel run //tools:check_build_files
PLAN
