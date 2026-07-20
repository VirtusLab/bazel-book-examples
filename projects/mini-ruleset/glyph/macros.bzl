"""Public macro helpers for Glyph.

Both macro styles live here so the 4.1 contrast is side by side:
`glyph_legacy_app` is a legacy macro (a plain Starlark function; its generated
targets are visible to callers after loading), and `glyph_app` is a symbolic
`macro(...)` with typed attributes that hides its private helper target. They
expand to the same two-target shape; only the authoring model differs.
"""

load("//glyph:providers.bzl", "GlyphInfo")
load("//glyph/internal:rules.bzl", "glyph_binary", "glyph_library")

def glyph_legacy_app(name, srcs, module, main_module, deps = [], exports = [], data = [], visibility = None):
    """Legacy macro that expands to a private glyph_library plus public glyph_binary.

    Args:
        name: Name of the public binary target produced by the macro.
        srcs: Glyph source files for the private helper library.
        module: Glyph module name provided by the private helper library.
        main_module: Glyph module used as the binary entry point.
        deps: Glyph libraries imported by the source module.
        exports: Glyph libraries re-exported by the private helper library.
        data: Runtime files declared by the private helper library.
        visibility: Visibility applied to the public binary target.
    """
    # Legacy macro: a plain function with no attribute schema. Its generated
    # targets are visible to the caller after loading, so inspect the expansion
    # with `bazel query //... --output=build`. Contrast with glyph_app below.
    glyph_library(
        name = name + "_lib",
        srcs = srcs,
        module = module,
        deps = deps,
        exports = exports,
        data = data,
        visibility = ["//visibility:private"],
    )
    glyph_binary(
        name = name,
        deps = [":" + name + "_lib"],
        main_module = main_module,
        visibility = visibility,
    )

def _glyph_app_impl(name, visibility, srcs, module, deps, exports, data, main_module):
    # Public API: symbolic macros can create private helper targets and expose
    # only the target named by the macro call. The generated library follows
    # the required name-prefix convention.
    glyph_library(
        name = name + "_lib",
        srcs = srcs,
        module = module,
        deps = deps,
        exports = exports,
        data = data,
        visibility = ["//visibility:private"],
    )
    glyph_binary(
        name = name,
        deps = [":" + name + "_lib"],
        main_module = main_module,
        visibility = visibility,
    )

glyph_app = macro(
    implementation = _glyph_app_impl,
    attrs = {
        # srcs and module define the *identity* of the generated module, so they
        # are configurable = False: the same macro call must produce the same
        # module name and sources in every configuration. deps/exports/data and
        # the entry point stay configurable, so a caller may still select() on
        # them per platform without changing what module this app is.
        "srcs": attr.label_list(
            allow_files = [".glyph"],
            configurable = False,
            doc = "Glyph source files for the private helper library.",
        ),
        "module": attr.string(
            mandatory = True,
            configurable = False,
            doc = "Glyph module provided by the helper library.",
        ),
        "deps": attr.label_list(
            providers = [GlyphInfo],
            doc = "Glyph libraries imported by the source module.",
        ),
        "exports": attr.label_list(
            providers = [GlyphInfo],
            doc = "Glyph libraries re-exported by the private helper library.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Runtime files declared by the private helper library.",
        ),
        "main_module": attr.string(
            mandatory = True,
            doc = "Glyph module used as the binary entry point.",
        ),
    },
    doc = "Symbolic macro that expands to a private glyph_library plus public glyph_binary.",
)
