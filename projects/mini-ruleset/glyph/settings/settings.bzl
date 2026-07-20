"""Build settings used by the Glyph examples."""

GlyphSettingInfo = provider(
    doc = "Typed value for a Glyph build setting.",
    fields = {
        "value": "The configured setting value.",
    },
)

def _glyph_mode_impl(ctx):
    if ctx.attr.values and ctx.build_setting_value not in ctx.attr.values:
        fail(
            "%s: expected one of %s, got %r" % (
                ctx.label,
                ", ".join(ctx.attr.values),
                ctx.build_setting_value,
            ),
            attr = "build_setting_default",
        )
    return [GlyphSettingInfo(value = ctx.build_setting_value)]

glyph_mode = rule(
    implementation = _glyph_mode_impl,
    build_setting = config.string(flag = True),
    attrs = {
        "values": attr.string_list(
            doc = "Allowed setting values. Empty means any string is accepted.",
        ),
    },
    doc = "String build setting used by Glyph rules and transitions.",
)
