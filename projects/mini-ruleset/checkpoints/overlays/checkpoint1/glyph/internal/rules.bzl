"""Temporary complete rule implementation for checkpoint 1."""

load("//glyph:providers.bzl", "GlyphInfo")

def _compile_impl(ctx):
    if not ctx.files.srcs:
        fail("%s: glyph_library requires at least one source file" % ctx.label, attr = "srcs")

    obj = ctx.actions.declare_file(ctx.label.name + ".glyphobj")
    iface = ctx.actions.declare_file(ctx.label.name + ".glyphiface")
    ctx.actions.write(obj, "module=%s\n" % ctx.attr.module)
    ctx.actions.write(iface, "module=%s\n" % ctx.attr.module)
    return [
        GlyphInfo(
            direct_modules = depset([ctx.attr.module]),
            interface_objects = depset([iface]),
            link_objects = depset([obj], order = "postorder"),
        ),
        DefaultInfo(files = depset([obj])),
    ]

glyph_library = rule(
    implementation = _compile_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".glyph"], mandatory = True),
        "module": attr.string(mandatory = True),
    },
    provides = [GlyphInfo],
)
