"""The child implementation calls ctx.super() twice."""

load("@upstream_rules//:report.bzl", "mode_report")

def _impl(ctx):
    ctx.super()
    return ctx.super()

twice_super_report = rule(
    implementation = _impl,
    parent = mode_report,
)
