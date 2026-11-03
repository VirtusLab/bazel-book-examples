load("@upstream_rules//:report.bzl", "mode_report_macro")

opt_mode_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = mode_report_macro,
)
