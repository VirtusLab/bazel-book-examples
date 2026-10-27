#!/usr/bin/env bash
# Runs each PROJECT.scl scenario in this snippet and asserts two things: the
# INFO/WARNING/ERROR lines Bazel prints, and the compilation mode the target
# was really built with (every genrule writes $(COMPILATION_MODE) to mode.txt).
set -euo pipefail

cd "$(dirname "$0")/.."

output=""

fail() {
  echo "assert_project_scl: $*" >&2
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

lacks() {
  if grep -F -- "$1" <<<"$output" >/dev/null; then
    fail "unexpected text: $1"
  fi
}

# Matches only the "uses a project file ... but also sets" warning line.
warning_line() {
  grep -F "WARNING: This build uses a project file ($1)" <<<"$output" ||
    fail "missing project-file warning for $1"
}

mode_is() {
  local got
  got="$(cat "bazel-bin/$1/mode.txt")"
  [[ $got == "$2" ]] || fail "bazel-bin/$1/mode.txt is '$got', expected '$2'"
}

# 1. No --scl_config: the is_default buildable unit is applied.
run ok build //warn:mode
has "INFO: Reading project settings from //warn:PROJECT.scl."
has "INFO: Applying flags from the config 'release' defined in //warn:PROJECT.scl: [--compilation_mode=opt]"
mode_is warn opt
# Bazel 9.1.0 quirk: module-registered rules_python --flag_alias entries count
# as user flags, so WARN warns even when the command line is empty.
warning_line //warn:PROJECT.scl | grep -F -- "'--flag_alias=" >/dev/null ||
  fail "expected the rules_python --flag_alias quirk in the WARN warning"

# 2. --scl_config picks a named buildable unit.
run ok build //warn:mode --scl_config=dev
has "INFO: Applying flags from the config 'dev' defined in //warn:PROJECT.scl: [--compilation_mode=dbg]"
mode_is warn dbg

# 3. WARN: an extra output-affecting flag is reported, the build continues.
run ok build //warn:mode --define=x=1
warning_line //warn:PROJECT.scl | grep -F -- "'--define=x=1'" >/dev/null ||
  fail "WARN warning does not list '--define=x=1'"
mode_is warn opt

# 4. WARN with a conflicting flag: still only a warning, and the project's
#    value wins over the command line.
run ok build //warn:mode --compilation_mode=dbg
warning_line //warn:PROJECT.scl | grep -F -- "'--compilation_mode=dbg'" >/dev/null ||
  fail "WARN warning does not list '--compilation_mode=dbg'"
mode_is warn opt

# 5. COMPATIBLE: a flag the selected config also sets, with another value, fails.
run error build //compatible:mode --compilation_mode=dbg
has "ERROR: Cannot parse options: This build uses a project file (//compatible:PROJECT.scl) that does not allow conflicting flags in the command line or user bazelrc. Found ['--compilation_mode=dbg']."

# 6. COMPATIBLE: an unrelated flag only warns.
run ok build //compatible:mode --define=x=1
warning_line //compatible:PROJECT.scl | grep -F -- "'--define=x=1'" >/dev/null ||
  fail "COMPATIBLE warning does not list '--define=x=1'"
mode_is compatible opt

# 7. COMPATIBLE: the same value as the config is not a conflict.
run ok build //compatible:mode --compilation_mode=opt
lacks "'--compilation_mode=opt'"
mode_is compatible opt

# 8. The checked-in workspace .bazelrc is not exempt: its cquery-only
#    --compilation_mode=dbg line conflicts with the COMPATIBLE project.
run error cquery //compatible:mode
has "Found ['--compilation_mode=dbg']."

# 9. STRICT fails with no user flags at all, because of the same rules_python
#    --flag_alias quirk as in step 1.
run error build //strict:mode
has "ERROR: Cannot parse options: This build uses a project file (//strict:PROJECT.scl) that does not allow output-affecting flags in the command line or user bazelrc. Found ["
has "'--flag_alias="

# 10. --noenforce_project_configs turns project resolution off entirely.
run ok build //warn:mode --noenforce_project_configs
lacks "Reading project settings"
lacks "Applying flags from the config"
mode_is warn fastbuild

# 11. A target with no PROJECT.scl above it builds with Bazel defaults alone,
#     but takes the project's flags when built together with //warn:mode.
run ok build //no_project:mode
lacks "Reading project settings"
mode_is no_project fastbuild
run ok build //warn:mode //no_project:mode
has "INFO: Applying flags from the config 'release' defined in //warn:PROJECT.scl: [--compilation_mode=opt]"
mode_is warn opt
mode_is no_project opt

# 12. The innermost PROJECT.scl owns a target.
run ok build //warn/nested:mode
has "INFO: Reading project settings from //warn/nested:PROJECT.scl."
has "INFO: Applying flags from the config 'nested_debug' defined in //warn/nested:PROJECT.scl: [--compilation_mode=dbg]"
mode_is warn/nested dbg

# 13. One invocation cannot mix targets owned by different PROJECT.scl files.
run error build //warn:mode //warn/nested:mode
has "ERROR: Mismatching default configs for a multi-project build. Targets have different project settings:"
has "  - //warn:mode -> //warn:PROJECT.scl"
has "  - //warn/nested:mode -> //warn/nested:PROJECT.scl"

# 14. An unknown --scl_config lists the valid ones with their descriptions.
run error build //warn:mode --scl_config=nope
has "ERROR: Cannot parse options: --scl_config=nope is not a valid configuration for this project."
has "-> Optimized build, applied when --scl_config is not set."
has "-> Debug build, selected with --scl_config=dev."

# 15. A lowercase project.scl is not a project file. Only checked on Linux:
#     a case-insensitive file system (the macOS default) could match it.
if [[ $(uname -s) == Linux ]]; then
  run ok build //lowercase:mode
  lacks "Reading project settings"
  mode_is lowercase fastbuild
fi

# 16. A project with no matching is_default unit requires --scl_config.
run error build //no_default:mode
has "ERROR: Cannot parse options: This project's builds must set --scl_config because no default config is defined."
run ok build //no_default:mode --scl_config=dev
has "INFO: Applying flags from the config 'dev' defined in //no_default:PROJECT.scl: [--compilation_mode=dbg]"
mode_is no_default dbg

echo "ok: PROJECT.scl defaults, --scl_config, WARN/COMPATIBLE/STRICT, rc files, and multi-project rules behave as documented"
