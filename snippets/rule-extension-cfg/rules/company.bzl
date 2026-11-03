"""Drop-in extension that keeps the upstream rule name and adds an output group."""

load("@upstream_rules//:report.bzl", _upstream_mode_report = "mode_report")

def _mode_report_impl(ctx):
    providers = ctx.super()

    # Built-in providers report their own type(). Custom ones such as ModeInfo report "struct".
    default_info = [p for p in providers if type(p) == "DefaultInfo"][0]
    report = default_info.files.to_list()[0]

    sorted_report = ctx.actions.declare_file(ctx.label.name + ".sorted.txt")
    ctx.actions.run_shell(
        inputs = [report],
        outputs = [sorted_report],
        command = 'LC_ALL=C sort "$1" > "$2"',
        arguments = [report.path, sorted_report.path],
    )
    return providers + [OutputGroupInfo(sorted = depset([sorted_report]))]

mode_report = rule(
    implementation = _mode_report_impl,
    parent = _upstream_mode_report,
)
