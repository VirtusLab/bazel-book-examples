#!/usr/bin/env bash
set -euo pipefail

snippet_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "STABLE_RELEASE_CHANNEL $(<"${snippet_root}/status/stable.txt")"
echo "BUILD_ATTEMPT $(<"${snippet_root}/status/volatile.txt")"
