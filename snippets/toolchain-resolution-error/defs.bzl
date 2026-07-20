def _demo_impl(ctx):
    return []

demo_rule = rule(
    implementation = _demo_impl,
    toolchains = ["//toolchain:demo_toolchain_type"],
)
