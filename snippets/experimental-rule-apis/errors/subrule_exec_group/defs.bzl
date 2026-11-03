"""subrule() has no exec_group parameter."""

def _impl(_ctx):
    return None

_helper = subrule(
    implementation = _impl,
    exec_group = "helper",
)

def _rule_impl(ctx):
    _helper()
    return []

exec_group_subrule_rule = rule(
    implementation = _rule_impl,
    subrules = [_helper],
)
