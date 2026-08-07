"""Public entry point for checkpoint 3."""

load("//glyph:providers.bzl", _GlyphInfo = "GlyphInfo")
load("//glyph/internal:rules.bzl", _glyph_library = "glyph_library")

visibility("public")

GlyphInfo = _GlyphInfo
glyph_library = _glyph_library
