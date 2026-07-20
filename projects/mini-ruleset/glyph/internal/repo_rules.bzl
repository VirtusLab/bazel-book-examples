"""Repository rules backing the local Glyph package registry."""

# Internal implementation: only the ruleset's own glyph/ tree may load this file
# (it is consumed by //glyph:extensions.bzl). visibility() enforces the
# "private implementation" boundary the README describes.
visibility("//glyph/...")

_REGISTRY = {
    "stdlib": {
        "1.0.0": {
            "module": "stdlib.print",
            "message": "hello from glyph stdlib",
            "imports": [],
            "deps": [],
        },
    },
    "math": {
        "1.0.0": {
            "module": "math.add",
            "message": "hello from glyph math",
            "imports": ["stdlib.print"],
            "deps": ["@glyph_stdlib//:lib"],
        },
    },
}

def _glyph_module_repo_impl(repository_ctx):
    package = repository_ctx.attr.package
    version = repository_ctx.attr.version
    if package not in _REGISTRY or version not in _REGISTRY[package]:
        fail("unknown Glyph package %s@%s" % (package, version))

    data = _REGISTRY[package][version]
    module_name = data["module"]

    # For teaching: the registry is an in-repo dict so this example works
    # offline. In a production ruleset, this repository rule would normally
    # download a hash-verified package archive or materialize data from a
    # checked-in lockfile.
    source_lines = ["module %s" % module_name]
    for imported in data["imports"]:
        source_lines.append("import %s" % imported)
    source_lines.append("message \"%s\"" % data["message"])
    repository_ctx.file("%s.glyph" % package, "\n".join(source_lines) + "\n")
    repository_ctx.file(
        "BUILD.bazel",
        """load("@rules_glyph//glyph:defs.bzl", "glyph_library")

glyph_library(
    name = "lib",
    srcs = ["{package}.glyph"],
    module = "{module}",
    deps = {deps},
    visibility = ["//visibility:public"],
)
""".format(
            package = package,
            module = module_name,
            deps = repr(data["deps"]),
        ),
    )

glyph_module_repo = repository_rule(
    implementation = _glyph_module_repo_impl,
    attrs = {
        "package": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    doc = "Generates a tiny external repo for one Glyph package.",
)
