#!/usr/bin/env bash
# Query-driven release workflow.
#
# Step 1: ask Bazel which targets carry tags = ["release"] — the "select
#         labels with bazel query" step.
# Step 2: hand those labels back to `bazel build` as explicit inputs.
#
# The whole script lives OUTSIDE the build graph: it does not appear as a
# Bazel target, no rule depends on it, and its incrementality story is "rerun
# the script". That is intentional. A collector target like //:all_release
# would force whole-repo loading every time someone wanted the release set.

set -euo pipefail

bazel_bin="${BAZEL:-bazel}"
if ! command -v "${bazel_bin}" >/dev/null 2>&1; then
  echo "no bazel binary on PATH (set BAZEL=... to override)" >&2
  exit 2
fi

cd "$(dirname "$0")/.."

targets_file="$(mktemp -t workflow-orchestration-release-targets.XXXXXX)"
trap 'rm -f "${targets_file}"' EXIT

# kind('.* rule', ...) keeps the result restricted to actual rule targets and
# drops generated source files that inherit tags via output_to_genfiles paths.
"${bazel_bin}" query \
  --output=label \
  --output_file="${targets_file}" \
  'attr("tags", "\brelease\b", kind(".* rule", //...))'

if [[ ! -s "${targets_file}" ]]; then
  echo "no release-tagged targets found; is the 'release' tag still applied?" >&2
  exit 1
fi

echo "release-tagged targets:"
sed 's/^/  /' "${targets_file}"

"${bazel_bin}" build --target_pattern_file="${targets_file}"
