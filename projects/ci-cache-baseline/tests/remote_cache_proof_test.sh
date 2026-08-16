#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  echo "Usage: $0 /path/to/bazel-remote [project-root]" >&2
  exit 2
fi

readonly remote_binary="$1"
readonly project_root="${2:-${PWD}}"
readonly bazel_command="${BAZEL_PROOF_BIN:-bazel}"

if [[ ! -x "${remote_binary}" ]]; then
  echo "bazel-remote is not executable: ${remote_binary}" >&2
  exit 1
fi
if [[ ! -f "${project_root}/MODULE.bazel" || ! -f "${project_root}/app/BUILD.bazel" ]]; then
  echo "Not a ci-cache-baseline workspace: ${project_root}" >&2
  exit 1
fi
if ! command -v "${bazel_command}" >/dev/null 2>&1; then
  echo "Bazel is required; set BAZEL_PROOF_BIN when it is not named bazel." >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to probe the bazel-remote status endpoint." >&2
  exit 1
fi

readonly temp_parent="${TMPDIR:-/tmp}"
work_dir="$(mktemp -d "${temp_parent%/}/ci-cache-proof.XXXXXX")"
readonly work_dir
readonly backend_cache="${work_dir}/backend-cache"
readonly backend_log="${work_dir}/backend.log"
readonly bypass_backend_cache="${work_dir}/bypass-backend-cache"
readonly bypass_backend_log="${work_dir}/bypass-backend.log"
readonly client_a_base="${work_dir}/client-a-output-base"
readonly client_b_base="${work_dir}/client-b-output-base"
readonly bypass_base="${work_dir}/bypass-output-base"
readonly client_a_log="${work_dir}/client-a-execution.json"
readonly client_b_log="${work_dir}/client-b-execution.json"
readonly bypass_log="${work_dir}/bypass-execution.json"
readonly client_a_record="${work_dir}/client-a-uppercase-message.json"
readonly client_b_record="${work_dir}/client-b-uppercase-message.json"
readonly bypass_record="${work_dir}/bypass-uppercase-message.json"

server_pid=""
bypass_server_pid=""
in_flight_server_pid=""
proof_passed=false

cleanup() {
  status="$?"
  for pid in "${in_flight_server_pid}" "${server_pid}" "${bypass_server_pid}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
    fi
    if [[ -n "${pid}" ]]; then
      wait "${pid}" 2>/dev/null || true
    fi
  done
  for output_base in "${client_a_base}" "${client_b_base}" "${bypass_base}"; do
    if [[ -d "${output_base}" ]]; then
      "${bazel_command}" --output_base="${output_base}" shutdown >/dev/null 2>&1 || true
    fi
  done
  if [[ "${proof_passed}" == true && "${work_dir}" == "${temp_parent%/}"/ci-cache-proof.* ]]; then
    rm -rf "${work_dir}"
  else
    echo "Proof artifacts retained at ${work_dir}" >&2
  fi
  exit "${status}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

started_pid=""
started_endpoint=""
start_backend() {
  cache_directory="$1"
  log_file="$2"
  mkdir -p "${cache_directory}"

  for ((attempt = 1; attempt <= 20; attempt++)); do
    port=$((18000 + (RANDOM % 20000)))
    candidate_endpoint="http://127.0.0.1:${port}"
    "${remote_binary}" \
      --dir="${cache_directory}" \
      --max_size=1 \
      --http_address="127.0.0.1:${port}" \
      --grpc_address=none \
      --log_timezone=none \
      --access_log_level=all \
      >"${log_file}" 2>&1 &
    candidate_pid="$!"
    in_flight_server_pid="${candidate_pid}"

    for ((readiness_attempt = 1; readiness_attempt <= 50; readiness_attempt++)); do
      if kill -0 "${candidate_pid}" 2>/dev/null && \
        curl --connect-timeout 1 --max-time 1 -fsS "${candidate_endpoint}/status" >/dev/null 2>&1; then
        started_pid="${candidate_pid}"
        started_endpoint="${candidate_endpoint}"
        return 0
      fi
      if ! kill -0 "${candidate_pid}" 2>/dev/null; then
        break
      fi
      sleep 0.1
    done
    if kill -0 "${candidate_pid}" 2>/dev/null; then
      kill "${candidate_pid}" 2>/dev/null || true
    fi
    wait "${candidate_pid}" 2>/dev/null || true
    in_flight_server_pid=""
  done

  echo "Could not start bazel-remote on an available loopback port." >&2
  return 1
}

start_backend "${backend_cache}" "${backend_log}"
server_pid="${started_pid}"
in_flight_server_pid=""
endpoint="${started_endpoint}"

run_build() {
  output_base="$1"
  execution_log="$2"
  shift 2
  "${bazel_command}" \
    --output_base="${output_base}" \
    --ignore_all_rc_files \
    build \
    --color=no \
    --curses=no \
    --noshow_progress \
    --symlink_prefix=/ \
    --lockfile_mode=off \
    --execution_log_json_file="${execution_log}" \
    "$@" \
    //app:uppercase_message
}

cd "${project_root}"

run_build \
  "${client_a_base}" \
  "${client_a_log}" \
  --remote_cache="${endpoint}" \
  --remote_upload_local_results=true

run_build \
  "${client_b_base}" \
  "${client_b_log}" \
  --remote_cache="${endpoint}" \
  --remote_upload_local_results=false

start_backend "${bypass_backend_cache}" "${bypass_backend_log}"
bypass_server_pid="${started_pid}"
in_flight_server_pid=""
bypass_endpoint="${started_endpoint}"

run_build \
  "${bypass_base}" \
  "${bypass_log}" \
  --remote_cache="${bypass_endpoint}" \
  --remote_upload_local_results=false

select_target_record() {
  input_file="$1"
  output_file="$2"
  if ! awk '
    function brace_delta(line,    character, delta, escaped, index_, in_string) {
      for (index_ = 1; index_ <= length(line); index_++) {
        character = substr(line, index_, 1)
        if (in_string) {
          if (escaped) {
            escaped = 0
          } else if (character == "\\") {
            escaped = 1
          } else if (character == "\"") {
            in_string = 0
          }
        } else if (character == "\"") {
          in_string = 1
        } else if (character == "{") {
          delta++
        } else if (character == "}") {
          delta--
        }
      }
      return delta
    }

    /^[[:space:]]*$/ { next }
    {
      if (depth == 0 && $0 !~ /^[[:space:]]*{/) {
        malformed = 1
      }
      record = record $0 ORS
      depth += brace_delta($0)
      if (depth < 0) {
        malformed = 1
      }
      if (depth == 0) {
        if (index(record, "\"targetLabel\": \"//app:uppercase_message\"")) {
          matches++
          selected = record
        }
        record = ""
      }
    }

    END {
      if (malformed || depth != 0 || matches != 1) {
        exit 42
      }
      printf "%s", selected
    }
  ' "${input_file}" >"${output_file}"; then
    echo "Expected exactly one complete execution-log record for //app:uppercase_message in ${input_file}." >&2
    exit 1
  fi
}

digest_after() {
  marker="$1"
  file="$2"
  awk -v marker="${marker}" 'BEGIN { FS = "\"" }
    index($0, marker) { found = 1; next }
    found && index($0, "\"hash\"") { matches++; value = $4; found = 0 }
    END {
      if (matches != 1 || value == "") exit 43
      print value
    }
  ' "${file}" || {
    echo "Could not extract one digest after ${marker} from ${file}." >&2
    exit 1
  }
}

string_field() {
  field="$1"
  file="$2"
  awk -v field="${field}" 'BEGIN { FS = "\"" }
    index($0, "\"" field "\":") { matches++; value = $4 }
    END {
      if (matches != 1 || value == "") exit 44
      print value
    }
  ' "${file}" || {
    echo "Could not extract one ${field} string from ${file}." >&2
    exit 1
  }
}

boolean_field() {
  field="$1"
  file="$2"
  awk -v field="${field}" '
    index($0, "\"" field "\":") {
      matches++
      if ($0 ~ /: true[,[:space:]]*$/) value = "true"
      else if ($0 ~ /: false[,[:space:]]*$/) value = "false"
      else invalid = 1
    }
    END {
      if (matches != 1 || invalid || value == "") exit 45
      print value
    }
  ' "${file}" || {
    echo "Could not extract one ${field} boolean from ${file}." >&2
    exit 1
  }
}

assert_backend_line() {
  pattern="$1"
  description="$2"
  log_file="${3:-${backend_log}}"
  if ! grep -E "${pattern}" "${log_file}" >/dev/null; then
    echo "Missing backend evidence: ${description}" >&2
    exit 1
  fi
}

select_target_record "${client_a_log}" "${client_a_record}"
select_target_record "${client_b_log}" "${client_b_record}"
select_target_record "${bypass_log}" "${bypass_record}"

client_a_digest="$(digest_after '"targetLabel": "//app:uppercase_message"' "${client_a_record}")"
client_b_digest="$(digest_after '"targetLabel": "//app:uppercase_message"' "${client_b_record}")"
bypass_digest="$(digest_after '"targetLabel": "//app:uppercase_message"' "${bypass_record}")"
client_a_output_digest="$(digest_after '"actualOutputs"' "${client_a_record}")"
client_b_output_digest="$(digest_after '"actualOutputs"' "${client_b_record}")"
bypass_output_digest="$(digest_after '"actualOutputs"' "${bypass_record}")"
client_a_runner="$(string_field runner "${client_a_record}")"
client_b_runner="$(string_field runner "${client_b_record}")"
bypass_runner="$(string_field runner "${bypass_record}")"
client_a_cache_hit="$(boolean_field cacheHit "${client_a_record}")"
client_b_cache_hit="$(boolean_field cacheHit "${client_b_record}")"
bypass_cache_hit="$(boolean_field cacheHit "${bypass_record}")"

if [[ "${client_a_digest}" != "${client_b_digest}" || "${client_a_digest}" != "${bypass_digest}" ]]; then
  echo "The three clients did not report the same action digest." >&2
  exit 1
fi
if [[ "${client_a_output_digest}" != "${client_b_output_digest}" || "${client_a_output_digest}" != "${bypass_output_digest}" ]]; then
  echo "The three clients did not report the same output digest." >&2
  exit 1
fi
if [[ "${client_a_cache_hit}" != false || "${client_a_runner}" == "remote cache hit" ]]; then
  echo "Client A did not establish local execution after a cache miss." >&2
  exit 1
fi
if [[ "${client_b_cache_hit}" != true || "${client_b_runner}" != "remote cache hit" ]]; then
  echo "Client B did not establish a remote cache hit." >&2
  exit 1
fi
if [[ "${bypass_cache_hit}" != false || "${bypass_runner}" == "remote cache hit" ]]; then
  echo "The empty-backend bypass did not establish local execution." >&2
  exit 1
fi

assert_backend_line " GET 404 .* /ac/${client_a_digest}$" "AC miss for client A"
assert_backend_line " PUT 200 .* /ac/${client_a_digest}$" "stored client A action result"
assert_backend_line " GET 200 .* /ac/${client_b_digest}$" "served action result to client B"
assert_backend_line " PUT 200 .* /cas/${client_a_output_digest}$" "stored output blob"
assert_backend_line " GET 200 .* /cas/${client_b_output_digest}$" "served output blob to client B"
assert_backend_line " GET 404 .* /ac/${bypass_digest}$" "AC miss from the empty bypass backend" "${bypass_backend_log}"
if grep -E " PUT 200 .* /(ac|cas)/" "${bypass_backend_log}" >/dev/null; then
  echo "The read-only bypass unexpectedly wrote to its empty backend." >&2
  exit 1
fi

echo
echo "SHARED REMOTE CACHE PROOF PASSED"
echo "client A: action ${client_a_digest}, runner '${client_a_runner}', cacheHit=false"
echo "backend: AC miss -> AC/CAS writes -> AC/CAS reads for the same digests"
echo "client B: action ${client_b_digest}, runner '${client_b_runner}', cacheHit=true"
echo "bypass:   runner '${bypass_runner}', cacheHit=false (empty backend, uploads disabled)"

proof_passed=true
