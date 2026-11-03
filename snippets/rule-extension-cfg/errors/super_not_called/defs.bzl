"""The child implementation never calls ctx.super()."""

load("@upstream_rules//:report.bzl", "mode_report")

def _impl(_ctx):
    return []

skip_super_report = rule(
    implementation = _impl,
    parent = mode_report,
)
