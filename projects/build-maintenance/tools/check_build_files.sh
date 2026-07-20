#!/usr/bin/env bash
set -euo pipefail

workspace="${BUILD_WORKSPACE_DIRECTORY:-${1:-}}"
if [[ -z "${workspace}" || ! -d "${workspace}" ]]; then
  echo "usage: bazel run //tools:check_build_files [workspace]" >&2
  exit 2
fi

files=(
  "${workspace}/MODULE.bazel"
  "${workspace}/app/BUILD.bazel"
  "${workspace}/logging/BUILD.bazel"
  "${workspace}/message/BUILD.bazel"
  "${workspace}/tools/BUILD.bazel"
  "${workspace}/unused/BUILD.bazel"
)

status=0
for file in "${files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "missing ${file}" >&2
    status=1
    continue
  fi

  if grep -n '[[:blank:]]$' "${file}"; then
    echo "trailing whitespace in ${file}" >&2
    status=1
  fi

  if grep -n $'^\t' "${file}"; then
    echo "tab indentation in ${file}" >&2
    status=1
  fi
done

if [[ "${status}" -eq 0 ]]; then
  echo "BUILD file style check passed for ${#files[@]} files"
fi

exit "${status}"
