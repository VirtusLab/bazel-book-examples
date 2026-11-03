"""Extensions that add an incoming opt transition to upstream rules."""

load("@upstream_rules//:report.bzl", "dbg_report", "mode_report")

def _opt_transition_impl(_settings, _attr):
    return {"//command_line_option:compilation_mode": "opt"}

opt_transition = transition(
    implementation = _opt_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

opt_mode_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = mode_report,
    cfg = opt_transition,
)

# The parent's own cfg runs after this one and writes the same setting.
opt_dbg_report = rule(
    implementation = lambda ctx: ctx.super(),
    parent = dbg_report,
    cfg = opt_transition,
)
