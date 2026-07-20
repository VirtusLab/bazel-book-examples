# Build Maintenance Workflow

This Level 3 project example is a compact workspace for BUILD-file maintenance
articles. It uses Java only because imports make dependency edges visible: if
`app/MaintenanceApp.java` imports `logging.AuditLog` and
`message.MessageTemplate`, `app/BUILD.bazel` must name `//logging:audit_log` and
`//message:message`.

The BUILD-maintenance stage of
[Build a Maintainable Bazel Workspace](../../../conspect/3-maintainer/3.8.1-build-maintainable-bazel-workspace.md)
uses this project as its concrete maintenance loop. This README remains the
reference map for the helper targets and intentionally stale dependency.

## What To Inspect

- `message/BUILD.bazel` generates `GeneratedMessage.java` with a `genrule`. The
  command uses declared inputs and outputs through `$(location ...)`, `$<`, `$@`,
  and `$(@D)`.
- `app/BUILD.bazel` keeps handwritten Java deps reviewable. One dependency on
  `//unused:unused_helper` is intentionally stale so the cleanup workflow has a
  concrete edge to remove.
- `tools/check_build_files.sh` is the lightweight quality gate this sample can
  validate without downloading formatter tools.
- `tools/print_format_plan.sh` shows where `buildifier -r .` belongs in the
  workflow.
- `tools/print_gazelle_plan.sh` describes the Gazelle update step a real
  language ruleset would run after source imports change.
- `tools/print_buildozer_plan.sh` prints buildozer edits instead of applying
  them, so reviewers can compare the command plan with the BUILD diff.

## Try These Commands

```bash
bazel build //...
bazel test //...
bazel run //app:maintenance_app
bazel run //tools:check_build_files
bazel run //tools:print_format_plan
bazel run //tools:print_gazelle_plan
bazel run //tools:print_buildozer_plan
```

The buildozer, Gazelle, and formatting helpers intentionally print commands
only. They show the *shape* of the maintenance loop — they are deliberately
**not** substitutes for the real tools:

- `tools/check_build_files.sh` is a tiny in-repo style check (trailing
  whitespace, tab indentation). Real repos still need a pinned `buildifier`
  (typically via `buildifier-prebuilt` or `rules_lint`).
- `tools/print_format_plan.sh` only prints the `buildifier -r .` command a real
  setup would run; nothing in this workspace actually invokes Buildifier.
- `tools/print_gazelle_plan.sh` does not invoke Gazelle. A real Gazelle
  integration installs a language ruleset (e.g. `rules_go`, `rules_python`,
  `bazel-contrib/rules_jvm`) and a `gazelle_binary`.
- `tools/print_buildozer_plan.sh` does not run `buildozer`. It prints the
  `add deps` / `replace deps` / `remove deps` lines a maintainer would review
  and feed into a real `buildozer` binary.
- The stale `//unused:unused_helper` edge in `app/BUILD.bazel` is the kind of
  finding `unused_deps` would emit. This example does not vendor `unused_deps`
  — a real workflow installs it from `bazelbuild/buildtools` and runs it
  against `java_library` targets.

The maintenance loop the helpers sketch:

1. Change source imports or generated files.
2. Regenerate or edit BUILD deps.
3. Format BUILD files.
4. Review and apply buildozer cleanup commands.
5. Build and test the workspace.
