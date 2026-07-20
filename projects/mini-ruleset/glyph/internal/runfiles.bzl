"""One runfiles-resolution convention, shared by every generated Glyph launcher.

The ruleset emits three bash launchers — the `glyph_test` runner, the
`glyph_debug_binary` wrapper, and the executable the compiler links — and every
one of them has to answer the same question at runtime: "where is my runfiles
tree?" Rather than hand-roll that lookup three slightly different ways, they all
call `glyph_runfiles_preamble()` so the convention lives in exactly one place.

The compiler (`compiler/glyphc.py`) emits the identical two lines from Python
because it is a separate program and cannot load Starlark; its comment points
back here so the two copies stay in lockstep.

A production ruleset would instead source the canonical runfiles library
(`@bazel_tools//tools/bash/runfiles`), which also handles repo mapping and
manifest-only runfiles on Windows. This teaching helper keeps the lookup visible
and dependency-free on purpose.
"""

# Internal implementation: only the ruleset's own glyph/ tree may load this file.
visibility("//glyph/...")

def glyph_runfiles_preamble(workspace_name):
    """Return the bash preamble that locates the current target's runfiles tree.

    It defines two shell variables used by every Glyph launcher:

      * `runfiles_root` — `RUNFILES_DIR` (exported by `bazel run`) or `TEST_SRCDIR`
        (exported by the test runner), falling back to the `$0.runfiles` sibling
        tree when neither is set.
      * `workspace` — the runfiles tree's top-level directory, i.e. the workspace
        name. `TEST_WORKSPACE` overrides it under `bazel test`; otherwise the real
        name the rule passes in is used, never a hardcoded "_main" (which would
        break the moment the launcher is consumed from another repository).

    A file at runfiles-relative path `<p>` is then `"$runfiles_root/$workspace/<p>"`.
    """
    return "\n".join([
        'runfiles_root="${RUNFILES_DIR:-${TEST_SRCDIR:-$0.runfiles}}"',
        'workspace="${TEST_WORKSPACE:-%s}"' % workspace_name,
    ])
