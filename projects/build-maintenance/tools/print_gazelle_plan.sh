#!/usr/bin/env bash
set -euo pipefail

cat <<'PLAN'
# Gazelle is not vendored in this lightweight Java example.
# The workflow below is the step a repo would run after source imports change.

gazelle -build_file_name=BUILD.bazel ./...

# Then review generated BUILD deps before applying cleanup:
git diff -- app/BUILD.bazel logging/BUILD.bazel message/BUILD.bazel
bazel run //tools:print_buildozer_plan
PLAN
