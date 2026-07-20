"""Analysis-phase tests for the public Glyph rule contract.

4.5.1 teaches three shapes of analysis test; this suite ships one of each:
  * a provider-contract test (what GlyphInfo carries),
  * an action-shape test (which actions the rule declares, and that the
    validation output stays out of the default files), and
  * a failure test (that a bad target is rejected with the expected message).
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//glyph:defs.bzl", "GlyphInfo", "glyph_library")

def _provider_contract_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[GlyphInfo]

    asserts.equals(env, ["tests.subject"], info.direct_modules.to_list())
    asserts.equals(env, ["tests.subject"], info.exported_modules.to_list())
    asserts.equals(env, ["tests.api", "tests.facade", "tests.subject"], sorted(info.modules.to_list()))
    asserts.equals(env, 3, len(info.link_objects.to_list()))
    asserts.equals(
        env,
        ["tests/analysis/data/runtime.txt"],
        sorted([file.short_path for file in info.runtime_files.to_list()]),
    )

    return analysistest.end(env)

_provider_contract_test = analysistest.make(_provider_contract_test_impl)

def _action_shape_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # The rule's scheduling is part of its public contract: a worker-backed
    # GlyphCompile plus the auto-run GlyphValidate. Assert on mnemonics rather
    # than command lines so the test survives argument reshuffling.
    mnemonics = [action.mnemonic for action in analysistest.target_actions(env)]
    asserts.true(env, "GlyphCompile" in mnemonics, "expected a GlyphCompile action, got %s" % mnemonics)
    asserts.true(env, "GlyphValidate" in mnemonics, "expected a GlyphValidate action, got %s" % mnemonics)

    # The validation marker is a validation output, not a default output. It must
    # travel through the _validation output group, never through DefaultInfo, or
    # it would become an ordinary dependency input for every consumer.
    default_files = [file.short_path for file in target[DefaultInfo].files.to_list()]
    asserts.false(
        env,
        [file for file in default_files if file.endswith(".validation")] != [],
        "validation output leaked into DefaultInfo.files: %s" % default_files,
    )

    return analysistest.end(env)

_action_shape_test = analysistest.make(_action_shape_test_impl)

def _rejects_empty_srcs_test_impl(ctx):
    env = analysistest.begin(ctx)

    # Lock down the user-facing diagnostic from _compile_impl. Because this is an
    # analysis-time fail(), an expect_failure analysis test is the right tool —
    # execution-phase failures live in //examples/errors instead.
    asserts.expect_failure(env, "glyph_library requires at least one source file")

    return analysistest.end(env)

_rejects_empty_srcs_test = analysistest.make(
    _rejects_empty_srcs_test_impl,
    expect_failure = True,
)

def glyph_analysis_test_suite(name):
    glyph_library(
        name = name + "_api",
        srcs = ["api.glyph"],
        module = "tests.api",
        tags = ["manual"],
    )

    glyph_library(
        name = name + "_facade",
        srcs = ["facade.glyph"],
        exports = [":" + name + "_api"],
        module = "tests.facade",
        tags = ["manual"],
    )

    glyph_library(
        name = name + "_subject",
        srcs = ["subject.glyph"],
        data = ["data/runtime.txt"],
        deps = [":" + name + "_facade"],
        module = "tests.subject",
        tags = ["manual"],
    )

    # Intentionally invalid subject for the failure test: no srcs. It is tagged
    # manual so `bazel build //...` never tries to analyze it directly.
    glyph_library(
        name = name + "_empty",
        srcs = [],
        module = "tests.empty",
        tags = ["manual"],
    )

    _provider_contract_test(
        name = name + "_provider",
        size = "small",
        target_under_test = ":" + name + "_subject",
    )

    _action_shape_test(
        name = name + "_actions",
        size = "small",
        target_under_test = ":" + name + "_subject",
    )

    _rejects_empty_srcs_test(
        name = name + "_rejects_empty_srcs",
        size = "small",
        target_under_test = ":" + name + "_empty",
    )

    # A test_suite keeps the historical //tests/analysis:glyph_analysis_test label
    # working (now as the umbrella for all three analysis tests).
    native.test_suite(
        name = name,
        tests = [
            ":" + name + "_provider",
            ":" + name + "_actions",
            ":" + name + "_rejects_empty_srcs",
        ],
    )
