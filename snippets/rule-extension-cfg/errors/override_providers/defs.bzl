"""Overrides deps but changes the providers that the parent requires."""

load("@upstream_rules//:report.bzl", "mode_report")

OtherInfo = provider(fields = [])

other_deps_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = mode_report,
    attrs = {"deps": attr.label_list(providers = [OtherInfo])},
)
