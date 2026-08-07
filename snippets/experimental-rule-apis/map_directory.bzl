def _map_each_file(template_ctx, *, input_directories, output_directories, tools, additional_inputs, additional_params):
    for child in input_directories["input"].children:
        output = template_ctx.declare_file(
            child.basename + ".copied",
            directory = output_directories["output"],
        )
        template_ctx.run(
            executable = tools["copy"],
            inputs = [child],
            outputs = [output],
            arguments = [child.path, output.path],
        )

def _mapped_files_impl(ctx):
    input_tree = ctx.actions.declare_directory(ctx.label.name + "_input")
    output_tree = ctx.actions.declare_directory(ctx.label.name + "_output")
    ctx.actions.run_shell(
        outputs = [input_tree],
        command = "mkdir -p $1; printf 'mapped file\\n' > $1/input.txt",
        arguments = [input_tree.path],
    )
    ctx.actions.map_directory(
        input_directories = {"input": input_tree},
        output_directories = {"output": output_tree},
        tools = {"copy": ctx.attr._copy[DefaultInfo].files_to_run},
        implementation = _map_each_file,
    )
    return [DefaultInfo(files = depset([output_tree]))]

mapped_files = rule(
    implementation = _mapped_files_impl,
    attrs = {
        "_copy": attr.label(
            default = Label("//:copy_tool"),
            executable = True,
            cfg = "exec",
        ),
    },
)
