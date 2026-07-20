"""Implementation details for the public Glyph rules."""

load("//glyph:providers.bzl", "GlyphInfo")
load("//glyph/internal:runfiles.bzl", "glyph_runfiles_preamble")
load("//glyph/settings:settings.bzl", "GlyphSettingInfo")
load("//glyph/toolchains:toolchain.bzl", "GLYPH_TOOLCHAIN_TYPE")

# Internal implementation: only the ruleset's own glyph/ tree may load this file.
# Downstream consumers go through the //glyph:defs.bzl facade. The README calls
# these files "private implementation"; visibility() turns that promise into an
# enforced boundary instead of a comment.
visibility("//glyph/...")

def _setting_value(target):
    return target[GlyphSettingInfo].value

def _resource_short_path(file):
    return file.short_path

def _exported_modules(deps):
    return depset(transitive = [dep[GlyphInfo].exported_modules for dep in deps])

def _interface_objects(deps):
    return depset(transitive = [dep[GlyphInfo].interface_objects for dep in deps])

def _link_modules(deps):
    return depset(transitive = [dep[GlyphInfo].modules for dep in deps])

def _link_objects(deps):
    # postorder: dependencies come before the targets that depend on them, so
    # the flattened list is a valid link order (a leaf library precedes the
    # module that links it). The order is only meaningful because a real linker
    # consumes it; that is exactly when 4.1.5 says to pick one. The order must be
    # consistent with the link_objects field below, which also declares
    # postorder — mismatched orders cannot be merged.
    return depset(transitive = [dep[GlyphInfo].link_objects for dep in deps], order = "postorder")

def _manifests(deps):
    return depset(transitive = [dep[GlyphInfo].manifests for dep in deps])

def _runtime_files(deps):
    return depset(transitive = [dep[GlyphInfo].runtime_files for dep in deps])

def _compile_impl(ctx):
    if not ctx.files.srcs:
        fail("%s: glyph_library requires at least one source file" % ctx.label, attr = "srcs")

    toolchain = ctx.toolchains[GLYPH_TOOLCHAIN_TYPE].glyph
    mode = _setting_value(ctx.attr._mode)
    target_os = _setting_value(ctx.attr._target_os)

    # One set of direct dependencies, read two ways. deps and exports are both
    # visible at compile and link time; the phases differ in which facet of
    # GlyphInfo they read: compile consumes the small interface_objects (one
    # module name each) plus this target's exported_modules, while link consumes
    # the transitive link_objects and module list. direct_modules is the single
    # source of truth those module facets are derived from, here and below.
    direct_deps = ctx.attr.deps + ctx.attr.exports
    direct_modules = depset([ctx.attr.module])
    exported_modules = depset(transitive = [direct_modules, _exported_modules(ctx.attr.exports)])
    compile_inputs = _interface_objects(direct_deps)

    obj = ctx.actions.declare_file(ctx.label.name + ".glyphobj")
    iface = ctx.actions.declare_file(ctx.label.name + ".glyphiface")
    manifest = ctx.actions.declare_file(ctx.label.name + ".glyphmanifest")

    # Persistent-worker compile. The executable is toolchain.worker, the adapter
    # documented in glyph/worker/glyph_worker.py (that file owns the "why a
    # wrapper" story). Two pieces wire this action to worker mode:
    #   1. use_param_file routes every argument through an @flagfile, which is the
    #      worker protocol's request payload.
    #   2. execution_requirements opts into the worker strategy and the protobuf
    #      protocol (Bazel's default).
    # Only GlyphCompile is worker-backed; link/report/validate call the plain
    # compiler one-shot via toolchain.compiler.
    args = ctx.actions.args()
    args.use_param_file("@%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("compile")
    args.add("--module", ctx.attr.module)
    args.add_all(ctx.files.srcs, before_each = "--src")
    args.add_all(compile_inputs, before_each = "--dep_iface")
    args.add_all(exported_modules, before_each = "--exported_module")
    args.add_all(ctx.files.data, map_each = _resource_short_path, before_each = "--resource")
    args.add("--mode", mode)
    args.add("--target_os", target_os)
    args.add("--out", obj)
    args.add("--iface", iface)
    args.add("--manifest", manifest)

    ctx.actions.run(
        executable = toolchain.worker,
        arguments = [args],
        inputs = depset(ctx.files.srcs, transitive = [compile_inputs]),
        outputs = [obj, iface, manifest],
        mnemonic = "GlyphCompile",
        progress_message = "Compiling Glyph module %{label}",
        execution_requirements = {
            "supports-workers": "1",
            "requires-worker-protocol": "proto",
        },
    )

    # Execution-phase validation action: it runs the compiler's `validate`
    # subcommand over the produced object and fails the build when the module is
    # malformed (e.g. a non-namespaced module name). Publishing it through
    # OutputGroupInfo(_validation = ...) makes every consumer inherit the gate,
    # and `--norun_validations` can opt out. Unlike a written marker, this action
    # can actually fail, which is the whole point of a validation output.
    # This is the rule-owned half of the 4.8.3 contrast; the infrastructure-owned
    # half is //tools/aspects:glyph_metadata_aspect.bzl. See //examples/errors for
    # a target that trips this gate on purpose.
    validation = ctx.actions.declare_file(ctx.label.name + ".validation")
    validation_args = ctx.actions.args()
    validation_args.add("validate")
    validation_args.add("--object", obj)
    validation_args.add("--out", validation)
    ctx.actions.run(
        executable = toolchain.compiler,
        arguments = [validation_args],
        inputs = [obj],
        outputs = [validation],
        mnemonic = "GlyphValidate",
        progress_message = "Validating Glyph module %{label}",
    )

    # direct_modules and exported_modules were computed above (the compile action
    # needs them). interface_objects propagate through exports only; link_objects
    # and the linked module list flow transitively through deps and exports.
    interface_objects = depset([iface], transitive = [_interface_objects(ctx.attr.exports)])

    # postorder so the link command line lists dependencies before dependents.
    # This target's own object is the direct element; because it is appended
    # after the transitive children in postorder, it lands last — the shape a
    # linker wants. See _link_objects above for why the orders must match.
    link_objects = depset([obj], transitive = [_link_objects(direct_deps)], order = "postorder")
    modules = depset(transitive = [direct_modules, _link_modules(direct_deps)])
    manifests = depset([manifest], transitive = [_manifests(direct_deps)])
    runtime_files = depset(ctx.files.data, transitive = [_runtime_files(direct_deps)])
    info = GlyphInfo(
        direct_modules = direct_modules,
        exported_modules = exported_modules,
        interface_objects = interface_objects,
        link_objects = link_objects,
        modules = modules,
        manifests = manifests,
        runtime_files = runtime_files,
    )
    return [
        info,
        DefaultInfo(
            files = depset([obj]),
            runfiles = ctx.runfiles(transitive_files = runtime_files),
        ),
        OutputGroupInfo(
            # The direct manifest for this target, and the transitive rollup of
            # every manifest reachable through deps/exports. The transitive group
            # is what makes GlyphInfo.manifests observable:
            #   bazel build <target> --output_groups=glyph_manifests
            glyph_manifest = depset([manifest]),
            glyph_manifests = manifests,
            _validation = depset([validation]),
        ),
    ]

glyph_library = rule(
    implementation = _compile_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".glyph"],
            mandatory = True,
            doc = "Glyph source files that declare exactly one module.",
        ),
        "module": attr.string(
            mandatory = True,
            doc = "Public Glyph module name provided by this target.",
        ),
        "deps": attr.label_list(
            providers = [GlyphInfo],
            doc = "Direct Glyph libraries used to compile and link this module.",
        ),
        "exports": attr.label_list(
            providers = [GlyphInfo],
            doc = "Glyph libraries re-exported to direct dependents, Java-style.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Runtime files declared by resource statements and carried into binaries through runfiles.",
        ),
        "_mode": attr.label(default = "//glyph/settings:mode"),
        "_target_os": attr.label(default = "//glyph/settings:target_os"),
    },
    # Advertise GlyphInfo so it is a checkable contract: both attr
    # `providers = [GlyphInfo]` and the glyph_metadata_aspect's
    # `required_providers = [GlyphInfo]` match on the *advertised* provider set.
    provides = [GlyphInfo],
    toolchains = [GLYPH_TOOLCHAIN_TYPE],
    doc = "Compiles Glyph source files into a Glyph object and provider.",
)

def _binary_impl(ctx):
    if not ctx.attr.deps:
        fail("%s: glyph_binary needs at least one glyph_library dep" % ctx.label, attr = "deps")

    toolchain = ctx.toolchains[GLYPH_TOOLCHAIN_TYPE].glyph
    objects = _link_objects(ctx.attr.deps)
    mode = _setting_value(ctx.attr._mode)
    target_os = _setting_value(ctx.attr._target_os)

    executable = ctx.actions.declare_file(ctx.label.name)
    args = ctx.actions.args()
    args.add("link")
    args.add("--main", ctx.attr.main_module)
    args.add_all(objects, before_each = "--object")
    args.add("--mode", mode)
    args.add("--target_os", target_os)
    # The linked binary reads resource data from its own runfiles. Passing the
    # workspace name lets the generated launcher template the real repo name for
    # its runfiles lookup instead of hardcoding "_main" — the same rule
    # ctx.workspace_name carries, matching glyph_debug_binary.
    args.add("--workspace_name", ctx.workspace_name)
    args.add("--out", executable)

    ctx.actions.run(
        executable = toolchain.compiler,
        arguments = [args],
        inputs = objects,
        outputs = [executable],
        mnemonic = "GlyphLink",
        progress_message = "Linking Glyph binary %{label}",
    )

    runtime_files = depset(ctx.files.data, transitive = [_runtime_files(ctx.attr.deps)])
    runfiles = ctx.runfiles(transitive_files = runtime_files)

    return [
        DefaultInfo(
            executable = executable,
            files = depset([executable]),
            runfiles = runfiles,
        ),
    ]

glyph_binary = rule(
    implementation = _binary_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [GlyphInfo],
            mandatory = True,
            doc = "Glyph libraries linked into this binary.",
        ),
        "main_module": attr.string(
            mandatory = True,
            doc = "Glyph module that provides the binary entry point.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Extra runtime files available when the binary is launched.",
        ),
        "_mode": attr.label(default = "//glyph/settings:mode"),
        "_target_os": attr.label(default = "//glyph/settings:target_os"),
    },
    executable = True,
    toolchains = [GLYPH_TOOLCHAIN_TYPE],
    doc = "Links Glyph libraries into an executable script.",
)

def _test_impl(ctx):
    runner = ctx.actions.declare_file(ctx.label.name)
    binary = ctx.executable.binary
    # The expected line is not baked into the script. It is read at runtime from
    # $GLYPH_TEST_EXPECTED, which the rule supplies through RunEnvironmentInfo
    # below. That is what makes the provider load-bearing: remove it and `set -u`
    # makes the test fail on an unbound variable.
    #
    # Runfiles are resolved through the shared glyph_runfiles_preamble() so the
    # test runner, the debug wrapper, and the linked binary all use one lookup.
    script = """#!/usr/bin/env bash
set -euo pipefail
{runfiles}
bin="$runfiles_root/$workspace/{binary_path}"
output="$("$bin")"
echo "$output"
grep -Fqx "$GLYPH_TEST_EXPECTED" <<< "$output"
""".format(
        runfiles = glyph_runfiles_preamble(ctx.workspace_name),
        binary_path = binary.short_path,
    )
    ctx.actions.write(
        output = runner,
        content = script,
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [binary]).merge(ctx.attr.binary[DefaultInfo].default_runfiles)
    return [
        DefaultInfo(executable = runner, runfiles = runfiles),
        RunEnvironmentInfo(environment = {"GLYPH_TEST_EXPECTED": ctx.attr.expected}),
    ]

glyph_test = rule(
    implementation = _test_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            cfg = "target",
            mandatory = True,
            doc = "Glyph binary to run under Bazel's test runner.",
        ),
        "expected": attr.string(
            mandatory = True,
            doc = "Exact output line expected from the binary.",
        ),
    },
    test = True,
    doc = "Runs a Glyph binary and checks one expected output line.",
)

def _report_impl(ctx):
    toolchain = ctx.exec_groups["glyph_report"].toolchains[GLYPH_TOOLCHAIN_TYPE].glyph
    objects = _link_objects(ctx.attr.deps)
    report = ctx.actions.declare_file(ctx.label.name + ".modules.txt")
    args = ctx.actions.args()
    args.add("report")
    args.add_all(objects, before_each = "--object")
    args.add("--out", report)
    ctx.actions.run(
        executable = toolchain.compiler,
        arguments = [args],
        inputs = objects,
        outputs = [report],
        mnemonic = "GlyphReport",
        progress_message = "Writing Glyph module report %{label}",
        exec_group = "glyph_report",
    )
    return [
        DefaultInfo(files = depset([report])),
        OutputGroupInfo(glyph_report = depset([report])),
    ]

glyph_report = rule(
    implementation = _report_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [GlyphInfo],
            mandatory = True,
            doc = "Glyph libraries included in the report.",
        ),
    },
    exec_groups = {
        # The report action runs in its own execution group, pinned via
        # exec_compatible_with to //platforms:report_pool. With both worker
        # platforms registered, Bazel must schedule GlyphReport on
        # //platforms:report_worker while GlyphCompile / GlyphLink stay on the
        # default general_worker — a concrete example of routing one action to a
        # dedicated pool (carrying its own exec_properties) without touching the
        # compile/link path. The group resolves its own copy of the Glyph
        # toolchain via ctx.exec_groups[...].toolchains.
        "glyph_report": exec_group(
            toolchains = [GLYPH_TOOLCHAIN_TYPE],
            exec_compatible_with = ["//platforms:report_pool"],
        ),
    },
    doc = "Routes report generation through a dedicated execution group pinned to the report worker pool.",
)
