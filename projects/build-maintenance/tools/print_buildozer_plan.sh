#!/usr/bin/env bash
set -euo pipefail

cat <<'PLAN'
# Review these commands before applying them with buildozer.
# They model the usual maintenance edits for app/BUILD.bazel.

buildozer 'add deps //logging:audit_log' //app:app_lib
buildozer 'replace deps //message:legacy_message //message:message' //app:app_lib
buildozer 'remove deps //unused:unused_helper' //app:app_lib
buildozer 'print rule' //app:app_lib

# For multi-edit reviews, put the commands in a file and run:
buildozer -f /tmp/build-maintenance.buildozer
PLAN
