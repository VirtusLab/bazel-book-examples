#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${TEST_SHARD_STATUS_FILE:-}" ]]; then
  touch "${TEST_SHARD_STATUS_FILE}"
fi

total="${TEST_TOTAL_SHARDS:-1}"
index="${TEST_SHARD_INDEX:-0}"

cases=(alpha beta gamma delta epsilon zeta)
selected=()

for i in "${!cases[@]}"; do
  if (( i % total == index )); then
    selected+=("${cases[i]}")
  fi
done

printf 'shard=%s/%s\n' "${index}" "${total}"
printf 'cases=%s\n' "${selected[*]}"

trace_dir="${TEST_UNDECLARED_OUTPUTS_DIR:-${TEST_TMPDIR}}"
printf 'shard=%s/%s\ncases=%s\n' "${index}" "${total}" "${selected[*]}" \
  > "${trace_dir}/shard-${index}.txt"
