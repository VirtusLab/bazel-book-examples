"""Temporary complete compiler-backed implementation for checkpoint 2."""

load("//glyph:providers.bzl", "GlyphInfo")

def _compile_impl(ctx):
    if not ctx.files.srcs:
        fail("%s: glyph_library requires at least one source file" % ctx.label, attr = "srcs")

    obj = ctx.actions.declare_file(ctx.label.name + ".glyphobj")
    iface = ctx.actions.declare_file(ctx.label.name + ".glyphiface")
    manifest = ctx.actions.declare_file(ctx.label.name + ".glyphmanifest")
    args = ctx.actions.args()
    args.add("compile")
    args.add("--module", ctx.attr.module)
    args.add_all(ctx.files.srcs, before_each = "--src")
    args.add("--mode", "opt")
    args.add("--target_os", "host")
    args.add("--out", obj)
    args.add("--iface", iface)
    args.add("--manifest", manifest)
    ctx.actions.run(
        executable = ctx.executable._compiler,
        arguments = [args],
        inputs = ctx.files.srcs,
        outputs = [obj, iface, manifest],
        mnemonic = "GlyphCompile",
        progress_message = "Compiling Glyph module %{label}",
    )
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
        "_compiler": attr.label(
            default = "//compiler:glyphc",
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [GlyphInfo],
)
