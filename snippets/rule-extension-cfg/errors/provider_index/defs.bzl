"""Indexes the ctx.super() result as if it were a Target."""

load("@upstream_rules//:report.bzl", "mode_report")

def _impl(ctx):
    providers = ctx.super()
    _default_info = providers[DefaultInfo]
    return providers

indexed_report = rule(
    implementation = _impl,
    parent = mode_report,
)
