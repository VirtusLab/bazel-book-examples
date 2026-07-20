def legacy_macro_select(name, os):
    if type(os) == "string" and os == "linux":
        cmd = "echo macro picked linux > $@"
    else:
        cmd = (
            "echo 'legacy macro saw a loading-phase value, not the resolved select() branch' >&2; " +
            "exit 1"
        )

    native.genrule(
        name = name,
        outs = [name + ".txt"],
        cmd = cmd,
    )
