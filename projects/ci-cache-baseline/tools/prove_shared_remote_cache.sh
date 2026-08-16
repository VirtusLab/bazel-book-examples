#!/usr/bin/env bash
set -euo pipefail

readonly BAZEL_REMOTE_VERSION="2.6.1"
readonly DOWNLOAD_BASE="https://github.com/buchgr/bazel-remote/releases/download/v${BAZEL_REMOTE_VERSION}"

command -v curl >/dev/null 2>&1 || {
  echo "curl is required to provision and probe bazel-remote." >&2
  exit 1
}

if [[ -f "${PWD}/MODULE.bazel" && -f "${PWD}/app/BUILD.bazel" ]]; then
  project_root="${PWD}"
elif [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" && -f "${BUILD_WORKSPACE_DIRECTORY}/app/BUILD.bazel" ]]; then
  project_root="${BUILD_WORKSPACE_DIRECTORY}"
else
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  project_root="$(cd "${script_dir}/.." && pwd)"
fi

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    platform="linux-amd64"
    expected_sha256="025d53aeb03a7fdd4a0e76262a5ae9eeee9f64d53ca510deff1c84cf3f276784"
    ;;
  Linux-aarch64 | Linux-arm64)
    platform="linux-arm64"
    expected_sha256="b8b9456d669d45bb8c5480ce0529ca4fa9d445e0c33b3aeed779df802d8164db"
    ;;
  Darwin-x86_64)
    platform="darwin-amd64"
    expected_sha256="02140dd308ca3f175ac198bf57a8b60c65d047d8957fa9edbe09e3d549735392"
    ;;
  Darwin-arm64)
    platform="darwin-arm64"
    expected_sha256="45a28a3b7e4466b5340577fc5618088e188e5ef306e02f0212108edee312bb1b"
    ;;
  *)
    echo "Unsupported host: $(uname -s) $(uname -m)." >&2
    echo "The pinned upstream binaries support Ubuntu 20.04+ and macOS 13+ on amd64 or arm64." >&2
    exit 1
    ;;
esac

echo "Pinned upstream host contract: Ubuntu 20.04+ or macOS 13+ on amd64/arm64."

cache_dir="${BAZEL_REMOTE_TOOL_CACHE:-${project_root}/bazel-cache-tools}"
remote_binary="${cache_dir}/bazel-remote-${BAZEL_REMOTE_VERSION}-${platform}"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "Neither sha256sum nor shasum is available." >&2
    return 1
  fi
}

if [[ ! -f "${remote_binary}" ]] || [[ "$(sha256_of "${remote_binary}")" != "${expected_sha256}" ]]; then
  mkdir -p "${cache_dir}"
  download_path="${remote_binary}.download.$$"
  trap 'rm -f "${download_path:-}"' EXIT
  echo "Downloading bazel-remote ${BAZEL_REMOTE_VERSION} for ${platform}..."
  curl --proto '=https' --tlsv1.2 -fsSL \
    "${DOWNLOAD_BASE}/bazel-remote-${BAZEL_REMOTE_VERSION}-${platform}" \
    -o "${download_path}"
  actual_sha256="$(sha256_of "${download_path}")"
  if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    echo "bazel-remote checksum mismatch." >&2
    echo "expected: ${expected_sha256}" >&2
    echo "actual:   ${actual_sha256}" >&2
    exit 1
  fi
  chmod 0755 "${download_path}"
  mv "${download_path}" "${remote_binary}"
  trap - EXIT
fi

actual_sha256="$(sha256_of "${remote_binary}")"
if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
  echo "Cached bazel-remote checksum mismatch after provisioning." >&2
  exit 1
fi

echo "Verified bazel-remote ${BAZEL_REMOTE_VERSION}: ${actual_sha256}"
exec "${project_root}/tests/remote_cache_proof_test.sh" "${remote_binary}" "${project_root}"
