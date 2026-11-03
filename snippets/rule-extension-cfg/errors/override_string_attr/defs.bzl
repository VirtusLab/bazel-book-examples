"""Overrides the parent's public string attribute."""

load("@upstream_rules//:report.bzl", "titled_report")

retitled_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = titled_report,
    attrs = {"title": attr.string(default = "override")},
)
