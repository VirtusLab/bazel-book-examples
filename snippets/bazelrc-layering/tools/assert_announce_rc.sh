#!/usr/bin/env bash
# Captures `bazel build --announce_rc --config=ci //app:app` output and asserts
# that the workspace .bazelrc is one of the rc files Bazel reports loading.
# This pins the user-facing behavior the article quotes: --announce_rc names
# the rc files and the lines that contributed flags.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

output="$(bazel build --announce_rc --config=ci //app:app 2>&1)"

# The robust signal that --announce_rc fired is that Bazel reports the workspace
# .bazelrc by absolute path. The exact section headers (e.g. "Inherited 'common'
# options:") are formatting Bazel may evolve between releases, so the assertion
# below intentionally avoids depending on them.
if ! grep -F "${repo_root}/.bazelrc" <<<"$output" >/dev/null; then
  echo "assert_announce_rc: --announce_rc did not mention the workspace .bazelrc path" >&2
  echo "expected substring: ${repo_root}/.bazelrc" >&2
  echo "----- captured output -----" >&2
  echo "$output" >&2
  exit 1
fi

echo "ok: --announce_rc reported ${repo_root}/.bazelrc"
