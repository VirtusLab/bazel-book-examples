"""Public providers for rules_glyph."""

GlyphInfo = provider(
    doc = "Carries the bootstrap compile and link contract for Glyph libraries.",
    fields = {
        "direct_modules": "depset of module names declared directly by this target.",
        "interface_objects": "depset of interface objects read by direct dependents.",
        "link_objects": "depset of compiled objects consumed by the linker.",
    },
)
