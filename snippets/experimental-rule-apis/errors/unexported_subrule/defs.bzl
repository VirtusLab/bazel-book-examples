"""A subrule reachable only through a struct, never assigned to a global."""

def _impl(_ctx):
    return None

helpers = struct(copy = subrule(implementation = _impl))

def _rule_impl(ctx):
    helpers.copy()
    return []

unexported_subrule_rule = rule(
    implementation = _rule_impl,
    subrules = [helpers.copy],
)
