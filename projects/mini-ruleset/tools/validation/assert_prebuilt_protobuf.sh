#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ruleset_root="$(cd -- "${script_dir}/../.." && pwd -P)"
cd "${ruleset_root}"

worker="//glyph/worker:worker"
representative="//examples/basic:hello_split_report"
generated_target="//tools/validation/protobuf:worker_protocol_pb2"
checked_in="${ruleset_root}/glyph/worker/worker_protocol_pb2.py"

# Analysis comes first and is the safety gate. Never materialize the drift-check
# target if any representative consumer configuration would compile Protobuf.
protobuf_cpp_actions="$({
  bazel aquery \
    "mnemonic(\"CppCompile\", deps(${representative}) union deps(${generated_target}))" \
    --output=text
})"
if grep -Eq '(^|/|@)protobuf[^/]*(/|\+)' <<<"${protobuf_cpp_actions}"; then
  echo "refusing to build: the configured graph contains Protobuf C++ compilation" >&2
  grep -E '(^|/|@)protobuf[^/]*(/|\+)' <<<"${protobuf_cpp_actions}" >&2 || true
  exit 1
fi

regeneration_action="$({
  bazel aquery \
    "mnemonic(\"RegenerateWorkerProto\", ${generated_target})" \
    --output=text
})"
if ! grep -Eq 'prebuilt_protoc\.[^/]+/bin/protoc(\.exe)?' <<<"${regeneration_action}"; then
  echo "maintainer regeneration did not select Protobuf's official prebuilt protoc" >&2
  exit 1
fi

consumer_codegen_actions="$({
  bazel aquery \
    "mnemonic(\"(GenProto|ProtoCompile|RegenerateWorkerProto)\", deps(${worker}))" \
    --output=text
})"
if [[ -n "${consumer_codegen_actions}" ]]; then
  echo "published worker still performs protobuf code generation" >&2
  exit 1
fi

wheel_runtime_path="$({
  bazel cquery \
    "somepath(${worker}, @rules_glyph_pip//protobuf)" \
    --output=label
})"
if [[ -z "${wheel_runtime_path}" ]]; then
  echo "published worker does not use the ruleset-private Protobuf wheel" >&2
  exit 1
fi

# Safe after the CppCompile guard: only the selected release-built protoc action
# may run. Compare its output so the checked-in binding cannot drift silently.
bazel build "${generated_target}"
bazel_bin="$(bazel info bazel-bin)"
regenerated="${bazel_bin}/tools/validation/protobuf/worker_protocol_pb2/glyph/worker/worker_protocol_pb2.py"

if ! cmp -s "${checked_in}" "${regenerated}"; then
  diff -u "${checked_in}" "${regenerated}" || true
  echo "checked-in worker_protocol_pb2.py is stale; regenerate ${generated_target}" >&2
  exit 1
fi

echo "verified prebuilt protoc regeneration, checked-in gencode, wheel runtime, and no Protobuf C++ actions"
