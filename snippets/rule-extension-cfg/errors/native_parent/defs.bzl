"""Uses a native rule as the parent."""

genrule_extension = rule(
    implementation = lambda ctx: ctx.super(),
    parent = native.genrule,
)
