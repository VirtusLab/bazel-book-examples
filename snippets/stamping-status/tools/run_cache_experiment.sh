#!/usr/bin/env bash
set -euo pipefail

snippet_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_base="$(mktemp -d "${TMPDIR:-/tmp}/stamping-status.XXXXXX")"
stable_file="${snippet_root}/status/stable.txt"
volatile_file="${snippet_root}/status/volatile.txt"
payload_file="${snippet_root}/app/payload.txt"
original_stable="$(<"${stable_file}")"
original_volatile="$(<"${volatile_file}")"
original_payload="$(<"${payload_file}")"

cleanup() {
  printf '%s\n' "${original_stable}" > "${stable_file}"
  printf '%s\n' "${original_volatile}" > "${volatile_file}"
  printf '%s\n' "${original_payload}" > "${payload_file}"
  bazel --output_base="${output_base}" shutdown >/dev/null 2>&1 || true
  rm -rf -- "${output_base}"
}
trap cleanup EXIT

build_number=0
run_build() {
  local label="$1"
  local expected_execution="$2"
  local expected_stable="$3"
  local expected_volatile="$4"
  local log="${output_base}/execution-${build_number}.json"
  build_number=$((build_number + 1))

  bazel --output_base="${output_base}" build \
    --noshow_progress \
    --execution_log_json_file="${log}" \
    --workspace_status_command=./tools/workspace_status.sh \
    //app:versioned >/dev/null

  local executions
  executions="$(grep -c '"mnemonic"[[:space:]]*:[[:space:]]*"StampedReport"' "${log}" || true)"
  if [[ "${executions}" != "${expected_execution}" ]]; then
    echo "${label}: expected ${expected_execution} StampedReport executions, got ${executions}" >&2
    exit 1
  fi
  grep -q "STABLE_RELEASE_CHANNEL ${expected_stable}" bazel-bin/app/versioned.txt
  grep -q "BUILD_ATTEMPT ${expected_volatile}" bazel-bin/app/versioned.txt
  printf '%-28s executions=%s output=%s/%s\n' \
    "${label}" "${executions}" "${expected_stable}" "${expected_volatile}"
}

printf '%s\n' release-a > "${stable_file}"
printf '%s\n' attempt-1 > "${volatile_file}"
printf '%s\n' payload=v1 > "${payload_file}"
run_build "1 initial" 1 release-a attempt-1

printf '%s\n' attempt-2 > "${volatile_file}"
run_build "2 volatile-only change" 0 release-a attempt-1

printf '%s\n' release-b > "${stable_file}"
run_build "3 stable change" 1 release-b attempt-2

printf '%s\n' attempt-3 > "${volatile_file}"
run_build "4 volatile-only change" 0 release-b attempt-2

printf '%s\n' payload=v2 > "${payload_file}"
run_build "5 ordinary input change" 1 release-b attempt-3
