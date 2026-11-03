load("@upstream_rules//:report.bzl", "sealed_report")

opt_sealed_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = sealed_report,
)
