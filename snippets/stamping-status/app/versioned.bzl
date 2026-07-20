def _versioned_info_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.run_shell(
        inputs = [ctx.file.src, ctx.info_file, ctx.version_file],
        outputs = [out],
        arguments = [
            ctx.file.src.path,
            ctx.info_file.path,
            ctx.version_file.path,
            out.path,
        ],
        command = """{
  cat "$1"
  grep '^STABLE_' "$2" || true
  grep '^BUILD_' "$3" || true
} > "$4"
""",
        mnemonic = "StampedReport",
    )
    return [DefaultInfo(files = depset([out]))]

versioned_info = rule(
    implementation = _versioned_info_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
    },
    doc = "Experiment rule that explicitly consumes both workspace-status files.",
)
