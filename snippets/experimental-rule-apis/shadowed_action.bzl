def _shadowed_action_probe_impl(ctx):
    original = ctx.actions.declare_file(ctx.label.name + ".original")
    ctx.actions.run(
        executable = ctx.executable._tool,
        inputs = [ctx.file.src],
        outputs = [original],
        arguments = ["emit", ctx.file.src.path, original.path],
        env = {"ORIGINAL_ENV": "from-original"},
    )

    # This is a test probe, not a production Action-discovery pattern.
    shadowed = ctx.created_actions().by_file[original]
    sidecar = ctx.actions.declare_file(ctx.label.name + ".sidecar")
    ctx.actions.run(
        executable = ctx.executable._tool,
        outputs = [sidecar],
        arguments = ["sidecar", ctx.file.src.path, sidecar.path],
        env = {"SIDECAR": "from-sidecar"},
        shadowed_action = shadowed,
    )
    return [DefaultInfo(files = depset([original, sidecar]))]

shadowed_action_probe = rule(
    implementation = _shadowed_action_probe_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "_tool": attr.label(
            default = Label("//:copy_tool"),
            executable = True,
            cfg = "exec",
        ),
    },
    _skylark_testable = True,
)
