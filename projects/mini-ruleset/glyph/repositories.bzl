"""Shared repository-materialization helpers for Glyph packages.

Bzlmod is the supported entry point: //glyph:extensions.bzl aggregates the
package tags from MODULE.bazel and calls the glyph_module_repo repository rule.
This module defines the repo-name convention used while the extension creates
repositories. `MODULE.bazel` still has to import the resulting apparent names
explicitly with `use_repo(...)`; the third-party example tests that public
contract. (A legacy WORKSPACE setup macro would reuse the same helper; this
example ships no WORKSPACE because it is Bzlmod-first.)
"""

# Every generated Glyph package repo carries this prefix: package "math" becomes
# @glyph_math. Centralized for every Starlark producer of those names.
GLYPH_REPO_PREFIX = "glyph_"

def glyph_repo_name(package):
    """Return the apparent external repo name for a Glyph package."""
    return GLYPH_REPO_PREFIX + package
