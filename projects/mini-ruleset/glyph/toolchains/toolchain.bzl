"""Toolchain contract for the Glyph compiler."""

visibility("public")

GlyphToolchainInfo = provider(
    doc = "Executable tools needed by Glyph rules.",
    fields = {
        "compiler": "FilesToRunProvider for the one-shot Glyph compiler/linker.",
        "worker": "FilesToRunProvider for the persistent-worker adapter that wraps the compiler.",
    },
)

GLYPH_TOOLCHAIN_TYPE = Label("//glyph/toolchains:toolchain_type")

def _glyph_toolchain_impl(ctx):
    # For teaching: this implementation points at a compiler built from source
    # (a py_binary in //compiler). In a production ruleset, the same field could
    # point at a downloaded SDK wrapper or a company-local compiler target. The
    # consuming rules do not care where the executable label came from.
    #
    # Carry the FilesToRunProvider, not the bare executable File: a py_binary is
    # a launcher that needs its .runfiles tree. Passing files_to_run to
    # ctx.actions.run(executable = ...) makes Bazel stage those runfiles
    # automatically, which a bare File would not.
    return [
        platform_common.ToolchainInfo(
            glyph = GlyphToolchainInfo(
                compiler = ctx.attr.compiler[DefaultInfo].files_to_run,
                worker = ctx.attr.worker[DefaultInfo].files_to_run,
            ),
        ),
    ]

glyph_toolchain = rule(
    implementation = _glyph_toolchain_impl,
    attrs = {
        "compiler": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "Executable Glyph compiler target (e.g. a py_binary) used in the execution configuration.",
        ),
        # The worker is a *separate* executable from the compiler: the
        # persistent-worker adapter (see glyph/worker/glyph_worker.py). Giving it
        # its own toolchain field keeps the boundary explicit — the compiler
        # stays a plain tool and the adapter is what Bazel talks to in worker
        # mode, the same way a production toolchain could wrap a downloaded SDK.
        "worker": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "Persistent-worker adapter that wraps the compiler, used in the execution configuration.",
        ),
    },
    doc = "Wraps an executable compiler and its persistent-worker adapter as a Glyph toolchain implementation.",
)
