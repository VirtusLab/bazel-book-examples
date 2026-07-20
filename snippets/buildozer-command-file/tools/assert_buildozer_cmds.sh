#!/usr/bin/env bash
set -euo pipefail

cmds="buildozer-cmds.txt"

test -f "${cmds}"
grep -q '^print rule|//lib:core$' "${cmds}"
grep -q '^add deps //base:logging|//lib:core$' "${cmds}"
grep -q '^print rule|//lib:\*$' "${cmds}"
grep -q '^remove srcs extra.txt|//lib:%filegroup$' "${cmds}"
grep -q '^set default_visibility //visibility:public|//lib:__pkg__$' "${cmds}"
