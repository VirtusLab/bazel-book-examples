"""Public providers for rules_glyph."""

GlyphInfo = provider(
    doc = "Carries the compile, link, and runtime contract for Glyph libraries.",
    fields = {
        "direct_modules": "depset of module names declared directly by this target; the source of truth exported_modules and modules are derived from.",
        "exported_modules": "depset of modules visible to direct dependents through deps/exports; recorded in the compile manifest.",
        "interface_objects": "depset of small interface objects (one module name each) read when compiling direct dependents, instead of the full link objects.",
        "link_objects": "depset of full compiled objects needed when linking binaries through this target.",
        "modules": "depset of Glyph module names linked through this target.",
        "manifests": "depset of human-readable compile manifests, surfaced through the glyph_manifests output group.",
        "runtime_files": "depset of files needed when linked Glyph binaries run.",
    },
)
