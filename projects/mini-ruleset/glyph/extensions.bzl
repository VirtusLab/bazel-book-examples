"""Bzlmod extension for local Glyph package dependencies."""

load("//glyph:repositories.bzl", "glyph_repo_name")
load("//glyph/internal:repo_rules.bzl", "glyph_module_repo")

_module_tag = tag_class(
    attrs = {
        "name": attr.string(
            mandatory = True,
            doc = "Glyph package name in the local teaching registry.",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Glyph package version in the local teaching registry.",
        ),
    },
)

def _glyph_deps_impl(module_ctx):
    requests = {}
    requesters = {}
    root_direct_deps = {}

    # Collect the graph-wide request set before creating repositories. Repeated
    # identical requests collapse to one repo; incompatible versions fail with
    # the two module names instead of surfacing later as a duplicate-repo error.
    for mod in module_ctx.modules:
        for tag in mod.tags.module:
            if tag.name in requests and requests[tag.name] != tag.version:
                fail(
                    "conflicting versions for Glyph package %s: %s from module %s, %s from module %s" % (
                        tag.name,
                        requests[tag.name],
                        requesters[tag.name],
                        tag.version,
                        mod.name,
                    ),
                )
            requests[tag.name] = tag.version
            requesters[tag.name] = mod.name
            if mod.is_root:
                root_direct_deps[glyph_repo_name(tag.name)] = True

    for package in sorted(requests):
        repo_name = glyph_repo_name(package)
        glyph_module_repo(
            name = repo_name,
            package = package,
            version = requests[package],
        )

    # Tell `bazel mod tidy` only which generated repos the root module requested
    # directly. Repos needed solely by non-root modules still exist, but are not
    # incorrectly suggested in the root's use_repo() declaration.
    return module_ctx.extension_metadata(
        root_module_direct_deps = sorted(root_direct_deps.keys()),
        root_module_direct_dev_deps = [],
    )

glyph_deps = module_extension(
    implementation = _glyph_deps_impl,
    tag_classes = {
        "module": _module_tag,
    },
    doc = "Generates external repos for Glyph packages declared in MODULE.bazel.",
)
