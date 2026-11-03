#!/usr/bin/env bash
# Runs each subrule failure case and asserts the error Bazel 9.1.0 reports.
set -euo pipefail

cd "$(dirname "$0")/.."

output=""

fail() {
  echo "assert_subrule_errors: $*" >&2
  echo "----- captured output -----" >&2
  echo "$output" >&2
  exit 1
}

# run ok|error <bazel args...>: runs Bazel, stores stdout+stderr in $output.
run() {
  local expect="$1"
  shift
  local status=0
  output="$(bazel "$@" 2>&1)" || status=$?
  if [[ $expect == ok && $status -ne 0 ]]; then
    fail "expected success (exit $status): bazel $*"
  fi
  if [[ $expect == error && $status -eq 0 ]]; then
    fail "expected failure: bazel $*"
  fi
}

has() {
  grep -F -- "$1" <<<"$output" >/dev/null || fail "missing expected text: $1"
}

# 1. The experimental API flag gates subrule calls.
run error build --noexperimental_rule_extension_api //:subrule_copy
has "Non-allowlisted attempt to use subrules."

# 2. subrule() has no exec_group parameter.
run error build //errors/subrule_exec_group:probe
has "subrule() got unexpected keyword argument 'exec_group'"

# 3. A subrule that reads its toolchain needs automatic exec groups on the
#    consuming rule. The same rule with _use_auto_exec_groups succeeds.
run error build //errors/subrule_toolchain:without_aeg
has "subrules using toolchains must enable automatic exec-groups"
run ok build //errors/subrule_toolchain:with_aeg

# 4. A subrule must be exported as a global of its .bzl file.
run error build //errors/unexported_subrule:probe
has "Invalid subrule hasn't been exported by a bzl file"

echo "assert_subrule_errors: all scenarios passed"
