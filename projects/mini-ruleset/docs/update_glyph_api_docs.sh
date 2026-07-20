#!/usr/bin/env bash
# Refresh the checked-in Stardoc golden (docs/glyph_api.md) from freshly
# generated output. Run it whenever a public doc string changes:
#   bazel run //docs:update_glyph_api_docs
set -euo pipefail

: "${BUILD_WORKSPACE_DIRECTORY:?run this with 'bazel run //docs:update_glyph_api_docs'}"

generated="$1"
if [[ ! -f "$generated" ]]; then
  # Fall back to a runfiles-relative lookup when cwd is not the runfiles root.
  generated="${RUNFILES_DIR:-$0.runfiles}/_main/$1"
fi

dest="$BUILD_WORKSPACE_DIRECTORY/docs/glyph_api.md"
cp -f "$generated" "$dest"
# Bazel outputs are read-only; the golden is a normal editable source file.
chmod u+w "$dest"
echo "Refreshed docs/glyph_api.md from Stardoc output."
