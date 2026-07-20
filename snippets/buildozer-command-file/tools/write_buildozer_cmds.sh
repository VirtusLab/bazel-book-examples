#!/usr/bin/env bash
set -euo pipefail

workspace="${BUILD_WORKSPACE_DIRECTORY:-$PWD}"
out="${workspace}/buildozer-cmds.txt"

cat > "${out}" <<'EOF'
print rule|//lib:core
add deps //base:logging|//lib:core
print rule|//lib:*
remove srcs extra.txt|//lib:%filegroup
set default_visibility //visibility:public|//lib:__pkg__
EOF

printf 'wrote %s\n' "${out}"
