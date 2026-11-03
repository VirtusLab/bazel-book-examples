"""Stand-in for a third-party ruleset: the consuming module may load it but not edit it."""

ModeInfo = provider(
    doc = "Compilation modes seen by a report target and its deps.",
    fields = {"lines": "depset of '<target name>: <compilation mode>' strings"},
)

def _mode_report_impl(ctx):
    line = "%s: %s" % (ctx.label.name, ctx.var["COMPILATION_MODE"])
    lines = depset(
        [line],
        transitive = [dep[ModeInfo].lines for dep in ctx.attr.deps],
        order = "preorder",
    )
    out = ctx.actions.declare_file(ctx.label.name + ".mode.txt")
    ctx.actions.write(out, "\n".join(lines.to_list()) + "\n")
    return [
        DefaultInfo(files = depset([out])),
        ModeInfo(lines = lines),
    ]

_ATTRS = {
    "deps": attr.label_list(providers = [ModeInfo]),
}

mode_report = rule(
    implementation = _mode_report_impl,
    attrs = _ATTRS,
)

def _dbg_transition_impl(_settings, _attr):
    return {"//command_line_option:compilation_mode": "dbg"}

dbg_transition = transition(
    implementation = _dbg_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

dbg_report = rule(
    implementation = _mode_report_impl,
    attrs = _ATTRS,
    cfg = dbg_transition,
)

sealed_report = rule(
    implementation = _mode_report_impl,
    attrs = _ATTRS,
    extendable = False,
)

def mode_report_macro(name, **kwargs):
    mode_report(name = name, **kwargs)

# A rule with a public string attribute and a private label attribute, used to
# show which inherited attributes an extension may override.
titled_report = rule(
    implementation = _mode_report_impl,
    attrs = _ATTRS | {
        "title": attr.string(),
        "_template": attr.label(
            default = Label("//:report.bzl"),
            allow_single_file = True,
        ),
    },
)
