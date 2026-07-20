# Mini Ruleset: `rules_glyph`

This project is a compact, complete teaching ruleset for a fictional compiled
language called Glyph. It is intentionally small, but it uses the same Bazel
boundaries a real ruleset uses: a public `.bzl` entry point, private
implementation files locked down with `visibility(...)`, custom providers,
declared actions, execution-phase validation, toolchains, module extensions,
aspects, tests, Stardoc-generated docs, and release scaffolding.

Glyph is modeled after the parts of Java rules that are useful for rule-author
education: source modules import other modules, `deps` are compile/link
dependencies, `exports` re-exposes a dependency's API to downstream users, and
`data` is runtime-only content delivered through runfiles. That gives the
example a real dependency contract without needing a real parser, type checker,
or classpath implementation.

For a guided reconstruction rather than a reference map, follow
[Build a Ruleset End-to-End](../../../conspect/4-architect/4.13.1-build-ruleset-end-to-end.md).
The repository keeps this finished tree rather than intermediate snapshots. The
walkthrough therefore offers a read-and-verify path over the current files and a
build-along path for a disposable copy or branch; both assemble the same
contracts in dependency order and return here for the complete file tree and
command catalog.

## Glyph Language Model

Glyph source files are tiny, but every directive maps to a Bazel contract:

```text
module app.core
import app.api
import stdlib.print
resource examples/basic/runtime/greeting.txt
message "hello from app.core"
entry main
```

- `module` is the public module name provided by a `glyph_library`.
- `import` must be satisfied by direct `deps` or by modules re-exported through a
  direct dependency's `exports`, similar to `java_library(exports = ...)`.
- `resource` must be present in the target's `data`. The compiler records it in
  the object file, and the linked binary reads it from runfiles at runtime.
- `message` becomes visible in the linked executable output.
- `entry` marks the binary's main module.

The dependency surface is deliberately Java-like, not Java-complete:

```starlark
glyph_library(
    name = "api",
    srcs = ["api.glyph"],
    module = "app.api",
    exports = ["@glyph_stdlib//:lib"],
)

glyph_library(
    name = "core",
    srcs = ["core.glyph"],
    module = "app.core",
    data = ["runtime/greeting.txt"],
    deps = [":api"],
)
```

`core.glyph` may import both `app.api` and `stdlib.print`: `app.api` comes from
the direct dependency, while `stdlib.print` is visible because `:api` exports the
stdlib library. The binary linked from `:core` also receives
`runtime/greeting.txt` through runfiles, but that resource is not a compile or
link action input unless a rule explicitly declares it that way.

The compiler is a `py_binary` built from source in this workspace. For teaching,
that keeps the project deterministic and self-contained. In a production
ruleset, the same compiler label might come from a downloaded SDK repository, an
internal tool wrapper, or a source-built compiler like this one. The rule
contract stays the same: the toolchain hands the rule a `FilesToRunProvider`,
and the rule runs it, with its runfiles, in the execution configuration.

## How To Read This Project

Use this repo in passes instead of reading every advanced feature at once:

1. **First build the consumer story.** Read `examples/basic/BUILD.bazel`, then
   run `bazel build //examples/basic:hello` and
   `bazel test //examples/basic:hello_test //examples/basic:runtime_data_test`.
   This is the normal ruleset shape: examples live inside the rules repository
   and load only the public `//glyph:defs.bzl` entry point.
2. **Then read the core rule contract.** Follow `glyph/defs.bzl` →
   `glyph/providers.bzl` → `glyph/internal/rules.bzl` for the public facade,
   `GlyphInfo`, declared actions, `DefaultInfo`, output groups, and runfiles.
3. **Then prove the public surface.** Read `tests/analysis/` for analysis-time
   contracts, `tests/integration/` for execution/runfiles behavior, and `docs/`
   for generated API docs guarded by a golden diff.
4. **Only then read the advanced surfaces.** Toolchains, workers, exec groups,
   transitions, aspects, repository rules, module extensions, and release
   scaffolding are intentionally present, but they are follow-up passes over the
   same small `examples/` targets rather than a second ruleset.

## Paths Through The Repo

- Start with `glyph/defs.bzl`. This is the public API: `glyph_library`,
  `glyph_binary`, `glyph_test`, `glyph_report`, transition wrappers, and helper
  macros. It declares `visibility("public")`; `glyph/internal/*.bzl` files
  declare `visibility("//glyph/...")`, so Bazel enforces the boundary.
- Read `glyph/providers.bzl` for the public `GlyphInfo` contract. It separates
  direct modules, exported API modules, compile interface objects, link objects,
  manifests, and runtime files. `link_objects` is built as a `postorder` depset
  in `glyph/internal/rules.bzl` so the flattened list is a valid link order
  (dependencies before dependents) — the one place the ruleset needs a specific
  depset order, exactly the criterion in 4.1.5.
- Read `glyph/internal/rules.bzl` for rule implementations, `deps` vs `exports`,
  `data` propagation through runfiles, `ctx.actions.args()`, output groups, a
  real `_validation` action, execution groups, `provides = [GlyphInfo]` (so the
  provider is an advertised, aspect-visible contract), and a `GlyphCompile`
  action wired through a protobuf persistent-worker adapter.
- Read `compiler/glyphc.py` to see the fake language semantics that make those
  rule contracts load-bearing. The compiler runs one command per invocation and
  knows nothing about workers or worker framing. Its link command does accept
  the workspace name and recorded runfiles paths as ordinary CLI data so the
  generated launcher can find runtime resources.
- Read `glyph/worker/glyph_worker.py` and `glyph/worker/worker_protocol.proto`
  for the persistent-worker adapter. This is the ruleset's responsibility, not
  the compiler's: it speaks Bazel's protobuf worker protocol (length-delimited
  `WorkRequest`/`WorkResponse` messages, the default protocol) and `import`s the
  compiler to run each request in-process, mirroring how `JavaBuilder` wraps
  `javac`. The same executable runs one-shot when the worker strategy is off.
- Read `MODULE.bazel`, the checked-in `worker_protocol_pb2.py`, and
  `tools/validation/assert_prebuilt_protobuf.sh` for the dependency-side
  performance choice. The published worker uses the official Python runtime
  wheel and checked-in official `protoc` output, so the published worker graph
  does not analyze a Protobuf source runtime or compiler. Protobuf 34.1 is
  maintainer-only: its upstream prebuilt toolchain regenerates the binding under
  `tools/validation/protobuf`, then a diff rejects drift. This keeps the private
  Protobuf toolchain API out of the published worker graph and does not register
  a Python proto language toolchain that could change a consumer's own proto
  targets. The compiler and worker select Python 3.13 through `rules_python`
  2.2.0; those versioned tools may download their interpreter, but they cannot
  replace the root consumer's default Python toolchain.

  The validation is deliberately fail-closed. It first uses `aquery` to reject
  every `CppCompile` action from Protobuf across a representative split-transition
  consumer and the regeneration target. Only after that analysis guard may it
  execute the small regeneration action, which must name a platform-specific
  `prebuilt_protoc` binary. Seeing `clang++` compile anything under external
  Protobuf is a failure, not an acceptable runtime caveat.
  `.bazelrc` adds a second guard: poison `per_file_copt` flags make an accidental
  Protobuf source edge fail on its first compile action rather than consuming a
  cold build before the regression becomes visible.
- Read `glyph/toolchains/toolchain.bzl` and `glyph/toolchains/BUILD.bazel` for
  the `toolchain_type`, `ToolchainInfo`, and source-built compiler toolchain.
- Read `platforms/BUILD.bazel` for the two root-only demo execution platforms.
  They are registered with `dev_dependency = True`, so consuming modules do not
  inherit this repository's scheduling policy. Here `glyph_report` requires
  `//platforms:report_pool`, so its report action runs on `report_worker` while
  unconstrained actions use `general_worker`; verify it with `bazel aquery`.
  A downstream root using `glyph_report` must register its own platform that
  provides the same capability.
- Read `glyph/settings/` and `glyph/transitions/` for Starlark build settings and
  all three transition shapes: an outgoing 1:1 debug transition
  (`glyph_debug_binary`, `attr.label(cfg=...)`), an incoming 1:1 debug transition
  (`glyph_debug_report`, `rule(cfg=...)`), and an outgoing split transition
  (`glyph_split_report`). `//glyph/settings:debug_mode` is a `config_setting`
  consumed by a real `select()` on `//examples/basic:hello`, so the debug
  transition and that `select()` form the transition/`select()` dual from 4.7.2.
- Read `glyph/extensions.bzl`, `glyph/repositories.bzl`, and
  `glyph/internal/repo_rules.bzl` for the local fake package registry. The
  extension aggregates package tags and calls the repository rule; the repo-name
  convention used by Starlark lives in `glyph/repositories.bzl`.
  `MODULE.bazel` must still import the generated public names explicitly with
  `use_repo()`, so the third-party build is the drift check. This models the
  shape of Maven/PyPI/Cargo-style dependency setup without network access.
- Read `tools/aspects/glyph_metadata_aspect.bzl` for an aspect that traverses
  Glyph dependencies and exposes a metadata output group. Its module docstring
  contrasts the aspect (infrastructure-owned overlay) with the rule-owned
  `_validation` action — the same cross-cutting question, two answers (4.8.3).
- Read `examples/basic/BUILD.bazel` for `hello_linux_only`: a target made
  incompatible with the host platform via `target_compatible_with` plus a custom
  constraint, so Bazel attaches `IncompatiblePlatformProvider` and skips it
  (4.6.7).
- Read `examples/errors/` for targets that intentionally trip the compile and
  `_validation` gates. They are tagged `manual` (so `//...` stays green); build
  one by name to see the exact failure Bazel prints.
- Read `tests/analysis/` for the three analysis-test shapes from 4.5.1 —
  provider contract, action shape (mnemonics plus "the `_validation` output
  never leaks into `DefaultInfo`"), and an `expect_failure` diagnostic test —
  bundled under the `//tests/analysis:glyph_analysis_test` suite. Read
  `tests/integration/` for runtime/runfiles coverage, `docs/` for a Stardoc
  target guarded by a `diff_test` against a checked-in golden
  (`docs/glyph_api.md`, refreshed with `bazel run //docs:update_glyph_api_docs`),
  and `tools/release/` plus `bcr/templates/` for publishing scaffolding.
- Read `.github/workflows/ci.yml` last. Its ordinary, worker, and one-shot
  checks deliberately use different targets: changing only `--strategy` does
  not invalidate an action key, so rebuilding one cached target would not prove
  that either execution path ran. The workflow also invokes every documented
  rejection target and fails if one unexpectedly turns green.

The `examples/` directory is executable documentation, not an internal shortcut.
It stays inside the ruleset repo, which is the common Bazel ruleset layout, but
the examples still use public loads and documented module-extension repos. CI
builds representative example targets so article snippets and the checked-in
examples drift together instead of becoming separate stories.

## Article Map

- `4.1`: `glyph_legacy_app` and `glyph_app` contrast legacy macros, symbolic
  macros, private helper targets, and the macro-vs-rule boundary.
- `4.2`: `glyph_library`, `glyph_binary`, `GlyphInfo`, declared actions,
  `DefaultInfo`, and `OutputGroupInfo` form the custom-rule core.
- `4.4`: `deps`, `exports`, `data`, runfiles, `RunEnvironmentInfo`, mnemonics,
  progress messages, and validation actions show the production rule surface.
- `4.4.4`: the `GlyphCompile` action declares `supports-workers` /
  `requires-worker-protocol: proto` and routes its arguments through an
  `@flagfile`, backed by the `//glyph/worker:worker` adapter (see the
  persistent-worker entry under "Paths Through The Repo" for how it works). It
  matches the conspect's "a worker is the tool itself or a wrapper around the
  tool" with the wrapper form.
- `4.5`: `tests/analysis` ships all three analysis-test shapes (provider,
  action, `expect_failure`); `tests/integration` and `examples/` cover
  execution-time behavior; and `//docs:glyph_api_docs` plus
  `//docs:glyph_api_docs_diff_test` demonstrate Stardoc guarded by a golden diff.
- `4.6`: `glyph/toolchains` and `platforms/` cover toolchain resolution and
  execution groups; `examples/basic:hello_linux_only` shows declarative
  incompatibility via `target_compatible_with` and `IncompatiblePlatformProvider`
  (4.6.7).
- `4.7`: `glyph/settings` and `glyph/transitions` cover build settings, a
  `config_setting` consumed by a real `select()` (the transition/`select()`
  dual), outgoing (`attr.label(cfg=...)`) and incoming (`rule(cfg=...)`)
  transitions, and a split transition.
- `4.8`: `tools/aspects/glyph_metadata_aspect.bzl` shows a cross-cutting metadata
  overlay, and its docstring contrasts aspects with the rule-owned `_validation`
  action — ownership, not capability, drives the choice (4.8.3).
- `4.9` and `4.10`: `glyph/internal/repo_rules.bzl` and `glyph/extensions.bzl`
  show repository materialization and Bzlmod aggregation.
- `4.11`: `.github/workflows`, `bcr/templates`, `MODULE.bazel`, and
  `tools/release` show ruleset handoff and publishing scaffolding. The worker
  protocol demonstrates a distribution boundary: consumers get generated code
  plus a release runtime, while maintainers regenerate it with the tool owner's
  upstream prebuilt compiler toolchain.

## Try These Commands

```bash
bazel build //examples/basic:hello
bazel build //examples/basic:bootstrap          # dependency-free capstone bootstrap target
bazel build //examples/basic:bootstrap_worker --strategy=GlyphCompile=worker  # guaranteed worker cache miss
bazel run //examples/basic:hello
bazel run //examples/basic:hello_debug          # debug transition + select() adds a "debug probe active" line
bazel build //examples/basic:macro_hello --strategy=GlyphCompile=worker   # execute through the protobuf worker
bazel build //examples/basic:legacy_hello --strategy=GlyphCompile=local    # execute the one-shot fallback
tools/validation/assert_prebuilt_protobuf.sh                         # aborts before any Protobuf C++ build
bazel test //examples/basic:hello_test //examples/basic:runtime_data_test
bazel test //tests/analysis:glyph_analysis_test //tests/integration:basic_smoke_test
bazel build //examples/third_party:uses_math
bazel build //examples/basic:module_report --output_groups=glyph_report
bazel aquery 'mnemonic("GlyphReport", //examples/basic:module_report)'
bazel build //examples/basic:module_report_debug   # incoming rule(cfg=...) => report says mode=debug with no flag
bazel build //examples/basic:metadata \
  --aspects=//tools/aspects:glyph_metadata_aspect.bzl%glyph_metadata_aspect \
  --output_groups=glyph_metadata
bazel build //examples/basic:core --output_groups=_validation
bazel build //examples/basic:core --output_groups=glyph_manifest   # this target's direct manifest
bazel build //examples/basic:core --output_groups=glyph_manifests  # transitive manifest rollup
bazel build //examples/basic:hello_split_report
bazel build //docs:glyph_api_docs
bazel test //docs:glyph_api_docs_diff_test      # fails if the checked-in docs golden is stale
bazel run //docs:update_glyph_api_docs          # refresh the golden after changing a doc string
bazel run //tools/release:print_release_plan

# These intentionally fail — build them to see the exact contract enforcement:
bazel build //examples/basic:hello_linux_only        # incompatible target platform
bazel build //examples/errors:missing_import          # import not in deps (compile)
bazel build //examples/errors:missing_resource        # resource not in data (compile)
bazel build //examples/errors:unnamespaced            # bad module name (_validation)
```

## What Is Deliberately Mocked

- The Glyph language is fake. The parser only checks a tiny module/import/
  resource/message format so the Bazel rule contracts stay readable.
- `exports` borrows the useful shape from Java rules, but it does not model Java
  ABI jars, strict deps diagnostics, annotation processing, or runtime classpath
  edge cases.
- The third-party package registry is local. A production ruleset would usually
  download release artifacts with hashes or read a lockfile produced by a
  language package manager.
- Docs are real and drift-checked: `//docs:glyph_api_docs` runs Stardoc over
  `glyph/defs.bzl`, and `//docs:glyph_api_docs_diff_test` fails the build if the
  checked-in golden `docs/glyph_api.md` no longer matches. Only *publishing* the
  docs, plus the BCR metadata and tag-gated release in `tools/release/` and
  `bcr/templates/`, is left as scaffolding so the example does not depend on a
  real publishing pipeline.
