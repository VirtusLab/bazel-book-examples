ArchInfo = provider(fields = ["cpu"])
CpuSettingInfo = provider(fields = ["value"])

def _cpu_setting_impl(ctx):
    return CpuSettingInfo(value = ctx.build_setting_value)

cpu_setting = rule(
    implementation = _cpu_setting_impl,
    build_setting = config.string(flag = True),
)

def _arch_dep_impl(ctx):
    return [ArchInfo(cpu = ctx.attr._cpu_setting[CpuSettingInfo].value)]

arch_dep = rule(
    implementation = _arch_dep_impl,
    attrs = {
        "_cpu_setting": attr.label(default = ":cpu_setting"),
    },
)

def _split_transition_impl(settings, attr):
    return {
        "branch_alpha": {"//:cpu_setting": "x86"},
        "branch_beta": {"//:cpu_setting": "arm64"},
    }

split_transition = transition(
    implementation = _split_transition_impl,
    inputs = [],
    outputs = ["//:cpu_setting"],
)

def _probe_impl(ctx):
    lines = []
    for key in sorted(ctx.split_attr.dep.keys()):
        lines.append("%s=%s" % (key, ctx.split_attr.dep[key][ArchInfo].cpu))

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, "\n".join(lines) + "\n")
    return [DefaultInfo(files = depset([out]))]

split_key_probe = rule(
    implementation = _probe_impl,
    attrs = {
        "dep": attr.label(cfg = split_transition, mandatory = True),
    },
)
