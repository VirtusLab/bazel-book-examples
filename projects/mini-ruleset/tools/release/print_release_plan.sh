#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
rules_glyph release checklist:
1. Run bazel test //...
2. Build //docs:glyph_api_docs and attach generated docs to the release.
3. Create a stable source archive from the release tag.
4. Fill bcr/templates/source.json with url, integrity, and strip_prefix.
5. Run the BCR presubmit matrix from bcr/templates/presubmit.yml.

For teaching: this script prints the release gate instead of publishing
anything. A production ruleset would wire these steps into tag-triggered CI.
EOF
