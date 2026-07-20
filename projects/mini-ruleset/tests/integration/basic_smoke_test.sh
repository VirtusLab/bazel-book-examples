#!/usr/bin/env bash
set -euo pipefail

bin="${TEST_SRCDIR}/${TEST_WORKSPACE}/examples/basic/hello"
output="$("${bin}")"
echo "${output}"
grep -Fqx "hello from app.core" <<< "${output}"
grep -Fqx "resource examples/basic/runtime/greeting.txt: hello from Glyph runtime data" <<< "${output}"
