#!/usr/bin/env bash
# Builds each rule-extension scenario in this snippet and asserts what reached
# the targets: every report file lists "<target>: <compilation mode>" for the
# target and its deps, so the file shows which configuration each one got.
set -euo pipefail

cd "$(dirname "$0")/.."

output=""

fail() {
  echo "assert_rule_extension: $*" >&2
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

# report_is <label> <expected contents>: compares the target's single output.
# cquery --output=files resolves the configuration-specific bazel-out path.
report_is() {
  local file got
  file="$(bazel cquery "$1" --output=files 2>/dev/null)"
  got="$(cat "$file")"
  [[ $got == "$2" ]] || fail "$1 ($file) is:
$got
expected:
$2"
}

# 1. The unextended upstream rule follows the command line: fastbuild.
run ok build //app:plain
report_is //app:plain "plain: fastbuild
lib: fastbuild"

# 2. The pass-through extension adds an incoming opt transition. It reaches
#    the deps too, so //app:lib is also configured in opt here.
run ok build //app:optimized
report_is //app:optimized "optimized: opt
lib: opt"

# 3. The parent rule has its own cfg that sets dbg. The parent's transition
#    runs after the child's, so the child's opt is overwritten.
run ok build //app:pinned
report_is //app:pinned "pinned: dbg
lib: dbg"

# 4. //app:lib now exists in two configurations in one build.
run ok cquery "deps(//app:plain) + deps(//app:optimized)"
[[ $(grep -c '^//app:lib (' <<<"$output") -eq 2 ]] || fail "expected //app:lib in two configurations"

# 5. query reports the child rule's own name as the kind.
run ok query "kind(opt_mode_report, //app:all)" --output=label_kind
has "opt_mode_report rule //app:optimized"

# 6. A drop-in extension that reuses the parent's name keeps kind() queries
#    working: //dropin targets match the same kind as the upstream targets.
run ok query 'kind("^mode_report rule$", //app:all + //dropin:all)' --output=label_kind
has "mode_report rule //app:plain"
has "mode_report rule //dropin:report"

# 7. The drop-in keeps the parent's providers and adds an output group.
run ok build //dropin:sorted
report_is //dropin:report "report: fastbuild
core: fastbuild"
report_is //dropin:sorted "core: fastbuild
report: fastbuild"

# 8. parent must be a rule. A macro wrapper is a plain function.
run error build //errors/extend_macro:report
has "Error in rule: Parent needs to be a Starlark rule, was function"

# 9. The parent's author can forbid extension with extendable = False.
run error build //errors/sealed_parent:report
has "Error in rule: The rule 'sealed_report' is not extendable."

# 10. Native rules cannot be parents either.
run error build //errors/native_parent:report
has "Error in rule: Parent needs to be a Starlark rule, was rule"

# 11. The child must call ctx.super() exactly once.
run error build //errors/super_not_called:report
has "'super' was not called."
run error build //errors/super_twice:report
has "'super' called the second time."

# 12. ctx.super() returns a plain list, not a Target.
run error build //errors/provider_index:report
has "got Provider for sequence index, want int"

# 13. A target returns at most one instance of each provider. The drop-in
#     extension already returns OutputGroupInfo, so appending another fails.
run error build //errors/duplicate_output_group:report
has "Multiple conflicting returned providers with key OutputGroupInfo"

# 14. Only public label attributes can be overridden, and an override keeps
#     the parent's required providers.
run error build //errors/override_string_attr:report
has "Only label types maybe be overridden."
run error build //errors/override_type_mismatch:report
has "Types of parent and child's attributes mismatch."
run error build //errors/override_private_attr:report
has "private attributes cannot be overridden."
run error build //errors/override_providers:report
has "can't override required providers"

echo "assert_rule_extension: all scenarios passed"
