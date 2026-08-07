def _copy_impl(ctx, src, _copy_tool):
    output = ctx.actions.declare_file(ctx.label.name + ".copied")
    ctx.actions.run(
        executable = _copy_tool,
        inputs = [src],
        outputs = [output],
        arguments = [src.path, output.path],
    )
    return output

_copy = subrule(
    implementation = _copy_impl,
    attrs = {
        "_copy_tool": attr.label(
            default = Label("//:copy_tool"),
            executable = True,
            cfg = "exec",
        ),
    },
)

def _subrule_copy_impl(ctx):
    output = _copy(src = ctx.file.src)
    return [DefaultInfo(files = depset([output]))]

subrule_copy = rule(
    implementation = _subrule_copy_impl,
    attrs = {"src": attr.label(allow_single_file = True, mandatory = True)},
    subrules = [_copy],
)
