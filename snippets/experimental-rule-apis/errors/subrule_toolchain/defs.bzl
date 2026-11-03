"""A subrule that declares a toolchain, called by a rule without automatic exec groups."""

def _impl(ctx):
    return ctx.toolchains["//errors/subrule_toolchain:toolchain_type"]

_helper = subrule(
    implementation = _impl,
    toolchains = ["//errors/subrule_toolchain:toolchain_type"],
)

def _rule_impl(ctx):
    _helper()
    return []

toolchain_subrule_rule = rule(
    implementation = _rule_impl,
    subrules = [_helper],
)

# The same rule opted in to automatic exec groups analyzes successfully.
toolchain_subrule_aeg_rule = rule(
    implementation = _rule_impl,
    attrs = {"_use_auto_exec_groups": attr.bool(default = True)},
    subrules = [_helper],
)

empty_toolchain = rule(implementation = lambda _ctx: [platform_common.ToolchainInfo()])
