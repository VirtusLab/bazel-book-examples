#!/usr/bin/env bash
set -u

if [[ "$#" -eq 0 ]]; then
  set -- //...
fi

set +e
bazel test --symlink_prefix=/ --config=ci "$@"
status="$?"
set -e

if [[ "$status" -eq 0 ]]; then
  echo "Bazel CI test command passed."
else
  echo "Bazel CI test command failed with exit code ${status}." >&2
  echo "Preserve this exit code so the CI platform records the Bazel result." >&2
fi

exit "$status"
