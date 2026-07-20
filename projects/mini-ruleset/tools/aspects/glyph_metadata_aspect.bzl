"""Command-line aspect that extracts Glyph module metadata.

4.8.3 — validation actions vs aspects, same question, two answers. This
ruleset ships both cross-cutting mechanisms, and the choice between them is
about *ownership*, not capability:

  * The `_validation` action in glyph/internal/rules.bzl is *rule-owned*. It
    lives inside glyph_library, so every consumer of the rule inherits the gate
    automatically and it can fail the build. Use it for checks intrinsic to the
    rule's contract (here: a Glyph object must be namespaced).
  * This aspect is *infrastructure-owned*. It is applied from the command line
    (`--aspects=...`) over targets the ruleset already produced, without
    changing the rule, and it exposes an optional `glyph_metadata` output group
    rather than blocking the build. Use it for project-wide overlays layered on
    top of rules you may not own.

The two compose: the rule guards its own correctness while an aspect adds an
external, opt-in view of the same graph.
"""

load("//glyph:providers.bzl", "GlyphInfo")

def _glyph_metadata_aspect_impl(target, ctx):
    # No manual `if GlyphInfo not in target` guard: required_providers (below)
    # already restricts this implementation to targets advertising GlyphInfo, so
    # the access is always safe and the check would be dead code.
    out = ctx.actions.declare_file(ctx.label.name + ".glyph_metadata.txt")
    modules = sorted(target[GlyphInfo].modules.to_list())
    ctx.actions.write(
        output = out,
        content = "\n".join(modules) + "\n",
    )

    # Follow the same edges Glyph dependency propagation uses: deps *and*
    # exports. Stopping at deps would silently skip modules reached only through
    # a dependency's exports, even though GlyphInfo.modules (written above)
    # already counts them — so the per-target overlay would disagree with the
    # provider it reports on. attr_aspects below must list the same attrs.
    transitive = []
    for attr_name in ("deps", "exports"):
        for dep in getattr(ctx.rule.attr, attr_name, []):
            if OutputGroupInfo in dep and hasattr(dep[OutputGroupInfo], "glyph_metadata"):
                transitive.append(dep[OutputGroupInfo].glyph_metadata)

    return [
        OutputGroupInfo(glyph_metadata = depset([out], transitive = transitive)),
    ]

glyph_metadata_aspect = aspect(
    implementation = _glyph_metadata_aspect_impl,
    attr_aspects = ["deps", "exports"],
    required_providers = [GlyphInfo],
    doc = "Traverses Glyph deps and exports, writing one metadata file per visited target.",
)
