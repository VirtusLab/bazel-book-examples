"""Maintainer-only Python worker-protocol binding regeneration."""

_PROTO_TOOLCHAIN_TYPE = "@protobuf//bazel/private:proto_toolchain_type"

def _generate_pb2_impl(ctx):
    toolchain = ctx.toolchains[_PROTO_TOOLCHAIN_TYPE].proto
    output_dir = ctx.actions.declare_directory(ctx.label.name)

    args = ctx.actions.args()
    args.add("--proto_path=.")
    args.add("--python_out=" + output_dir.path)
    args.add(ctx.file.src.path)

    ctx.actions.run(
        arguments = [args],
        executable = toolchain.proto_compiler,
        inputs = [ctx.file.src],
        mnemonic = "RegenerateWorkerProto",
        outputs = [output_dir],
        progress_message = "Regenerating checked-in worker protobuf bindings",
        tools = [toolchain.proto_compiler],
    )

    return [DefaultInfo(files = depset([output_dir]))]

generate_pb2 = rule(
    implementation = _generate_pb2_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = [".proto"],
            mandatory = True,
        ),
    },
    toolchains = [_PROTO_TOOLCHAIN_TYPE],
)
