"""Small transition examples used by the Glyph ruleset.

Both attachment points from 4.7.2 are shown side by side:

  * glyph_debug_binary / glyph_split_report attach a transition to an *attribute*
    (`attr.label(cfg = ...)`) — an outgoing-edge transition. The rule keeps its
    own configuration; only the dependency subtree under that attribute moves.
    Outgoing transitions may be 1:1 (debug) or 1:N (the os split).
  * glyph_debug_report attaches a transition to the *rule* (`rule(cfg = ...)`) —
    an incoming-edge transition. The rule re-enters its own analysis under the
    new configuration, so it and its whole subtree see mode=debug. Incoming
    transitions must be 1:1.
"""

load("//glyph:providers.bzl", "GlyphInfo")
load("//glyph/internal:runfiles.bzl", "glyph_runfiles_preamble")
load("//glyph/settings:settings.bzl", "GlyphSettingInfo")

def _debug_transition_impl(settings, attr):
    return {"//glyph/settings:mode": "debug"}

_debug_transition = transition(
    implementation = _debug_transition_impl,
    inputs = [],
    outputs = ["//glyph/settings:mode"],
)

def _split_os_transition_impl(settings, attr):
    return {
        "linux_branch": {"//glyph/settings:target_os": "linux"},
        "macos_branch": {"//glyph/settings:target_os": "macos"},
    }

_split_os_transition = transition(
    implementation = _split_os_transition_impl,
    inputs = [],
    outputs = ["//glyph/settings:target_os"],
)

def _debug_binary_impl(ctx):
    binary = ctx.executable.binary

    # An outgoing transition forces ctx.attr.binary to be a list, even for a
    # 1:1 transition (it would be keyed via ctx.split_attr for a split). Read
    # the single transitioned target at index 0.
    binary_target = ctx.attr.binary[0]
    runner = ctx.actions.declare_file(ctx.label.name)

    # Locate the wrapped binary inside our own runfiles using the shared
    # glyph_runfiles_preamble() (the one convention every Glyph launcher uses).
    # We then *export* RUNFILES_DIR before exec: the wrapped binary is launched
    # by absolute path, so without an inherited RUNFILES_DIR it would fall back
    # to "$0.runfiles" (which does not exist next to the inner executable) and
    # fail to find its own runfiles — e.g. resource data carried through `data`.
    ctx.actions.write(
        output = runner,
        content = """#!/usr/bin/env bash
set -euo pipefail
{runfiles}
export RUNFILES_DIR="$runfiles_root"
exec "$runfiles_root/$workspace/{binary_path}" "$@"
""".format(
            runfiles = glyph_runfiles_preamble(ctx.workspace_name),
            binary_path = binary.short_path,
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [binary]).merge(binary_target[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = runner, runfiles = runfiles)]

glyph_debug_binary = rule(
    implementation = _debug_binary_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            cfg = _debug_transition,
            mandatory = True,
            doc = "Glyph binary rebuilt with //glyph/settings:mode=debug.",
        ),
    },
    executable = True,
    doc = "Wraps a binary dependency behind an outgoing debug transition.",
)

def _split_report_impl(ctx):
    # Each attr carrying the split transition is keyed by branch in ctx.split_attr
    # (a single attr.label yields one Target per branch, not a list). Both
    # `binary` and `_target_os` are split the same way, so the same branch keys
    # line up. Reading GlyphSettingInfo off the _target_os dependency proves each
    # branch was configured under a *different* //glyph/settings:target_os value —
    # the label alone is identical across branches, only the configuration differs.
    lines = ["split branches:"]
    for key in sorted(ctx.split_attr.binary.keys()):
        binary = ctx.split_attr.binary[key]
        target_os = ctx.split_attr._target_os[key][GlyphSettingInfo].value
        lines.append("%s: target_os=%s binary=%s" % (key, target_os, binary.label))
    report = ctx.actions.declare_file(ctx.label.name + ".split.txt")
    ctx.actions.write(
        output = report,
        content = "\n".join(lines) + "\n",
    )
    return [DefaultInfo(files = depset([report]))]

glyph_split_report = rule(
    implementation = _split_report_impl,
    attrs = {
        "binary": attr.label(
            cfg = _split_os_transition,
            mandatory = True,
            doc = "Binary analyzed once for linux and once for macos branch keys.",
        ),
        "_target_os": attr.label(
            default = "//glyph/settings:target_os",
            cfg = _split_os_transition,
            doc = "The target_os build setting, read once per split branch to show its configured value.",
        ),
    },
    doc = "Demonstrates a dict-of-dicts split transition and reading per-branch configured settings via ctx.split_attr.",
)

def _debug_report_impl(ctx):
    # Because the transition is attached to the rule itself (incoming edge), this
    # analysis already runs under mode=debug — nobody passed --//glyph/settings:mode
    # on the command line. Reading the mode back off the private _mode dep proves
    # the rule re-entered its own analysis under the transitioned configuration.
    # Contrast glyph_debug_binary, where the wrapper stays in the default
    # configuration and only its `binary` dependency is transitioned.
    mode = _setting_value(ctx.attr._mode)
    modules = depset(transitive = [dep[GlyphInfo].modules for dep in ctx.attr.deps]).to_list()
    report = ctx.actions.declare_file(ctx.label.name + ".incoming.txt")
    ctx.actions.write(
        output = report,
        content = "mode=%s\n%s\n" % (mode, "\n".join(sorted(modules))),
    )
    return [DefaultInfo(files = depset([report]))]

def _setting_value(target):
    return target[GlyphSettingInfo].value

glyph_debug_report = rule(
    implementation = _debug_report_impl,
    # Incoming-edge transition: applied to the rule, not an attribute. The rule
    # (and its dependency subtree) is analyzed under mode=debug. Incoming
    # transitions must be 1:1, which _debug_transition is.
    cfg = _debug_transition,
    attrs = {
        "deps": attr.label_list(
            providers = [GlyphInfo],
            mandatory = True,
            doc = "Glyph libraries whose module list is reported under the debug configuration.",
        ),
        "_mode": attr.label(default = "//glyph/settings:mode"),
    },
    doc = "Reports the module list under a rule-level (incoming) debug transition, so mode=debug without any command-line flag.",
)
