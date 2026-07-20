"""Public entry point for rules_glyph.

Public API: examples and downstream users should load from this file instead of
`glyph/internal/...`. The internal files are free to move; this facade is the
compatibility contract.
"""

load(
    "//glyph:macros.bzl",
    _glyph_app = "glyph_app",
    _glyph_legacy_app = "glyph_legacy_app",
)
load("//glyph:providers.bzl", _GlyphInfo = "GlyphInfo")
load(
    "//glyph/internal:rules.bzl",
    _glyph_binary = "glyph_binary",
    _glyph_library = "glyph_library",
    _glyph_report = "glyph_report",
    _glyph_test = "glyph_test",
)
load(
    "//glyph/transitions:transitions.bzl",
    _glyph_debug_binary = "glyph_debug_binary",
    _glyph_debug_report = "glyph_debug_report",
    _glyph_split_report = "glyph_split_report",
)

# Public facade: any package, including downstream modules, may load this file.
# Stated explicitly so the contrast with the visibility("//glyph/...") internal
# files is visible at a glance.
visibility("public")

# Re-export under public names. Loading each symbol above under a `_`-prefixed
# alias keeps the *imported* symbols private to this file (a plain `load()`
# would itself re-export them), so this list is the exact public surface. There
# is no Starlark equivalent of Python's `__all__`: a .bzl file exports every
# top-level symbol whose name does not start with `_`, gated by visibility().
GlyphInfo = _GlyphInfo
glyph_app = _glyph_app
glyph_binary = _glyph_binary
glyph_debug_binary = _glyph_debug_binary
glyph_debug_report = _glyph_debug_report
glyph_legacy_app = _glyph_legacy_app
glyph_library = _glyph_library
glyph_report = _glyph_report
glyph_split_report = _glyph_split_report
glyph_test = _glyph_test
