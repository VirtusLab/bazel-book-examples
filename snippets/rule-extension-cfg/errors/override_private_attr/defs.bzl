"""Overrides the parent's private label attribute."""

load("@upstream_rules//:report.bzl", "titled_report")

retemplated_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = titled_report,
    attrs = {"_template": attr.label(default = Label("//app:BUILD.bazel"), allow_single_file = True)},
)
