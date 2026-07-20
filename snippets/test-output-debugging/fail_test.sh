#!/usr/bin/env bash
set -euo pipefail

echo "fail stdout"
echo "fail stderr" >&2
exit 1
