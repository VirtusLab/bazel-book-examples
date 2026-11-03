"""Overrides the parent's label-list deps attribute with a string list."""

load("@upstream_rules//:report.bzl", "mode_report")

string_deps_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = mode_report,
    attrs = {"deps": attr.string_list()},
)
