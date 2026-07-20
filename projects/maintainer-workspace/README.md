# Maintainer Workspace

This example is a compact Level 3 reference workspace. It builds a small Java
application, but it also shows the files a team-maintained Bazel repo usually
needs together: `MODULE.bazel`, `.bazelrc`, platform targets, configurable
attributes, target compatibility, and a Bazelisk `tools/bazel` wrapper.

For the incremental teaching path through these files, read
[Build a Maintainable Bazel Workspace](../../../conspect/3-maintainer/3.8.1-build-maintainable-bazel-workspace.md).
This README remains the compact reference map for the finished project.

## What To Inspect

- `MODULE.bazel` declares direct module dependencies and uses a local module
  extension to create `@release_policy`.
- `.bazelrc` keeps shared configs for CI, release, Linux, and macOS invocations,
  selects a remote Java runtime so the sample does not depend on `JAVA_HOME`,
  blocks sandboxed action network access by default, and gives CI persistent
  repository- and disk-cache paths.
- `.github/workflows/bazel.yml` restores Bazelisk, repository, and disk caches,
  runs the same broad test command maintainers use locally, and shuts down the
  Bazel server before the action saves caches.
- `tools/ci_bazel.sh` is the deliberately small CI entry point. It defaults to
  `//...` and preserves Bazel's exit status.
- `platforms/BUILD.bazel` defines target platforms from standard `@platforms`
  constraints plus one project-specific `libc` constraint setting.
- `app/BUILD.bazel` uses `select()` to choose platform-specific Java sources and
  release-mode arguments. The `release_build` condition matches
  `--compilation_mode=opt`; `--config=release` is just the named `.bazelrc`
  config that sets that flag.
- `app:maintainer_app` compiles through `java_library` and `java_binary`; this is
  the main "real build" path for the sample.
- `app:maintainer_app` passes `@release_policy//:policy.txt` with
  `$(rlocationpath ...)` and resolves it from Java runfiles at runtime, so it
  does not depend on an external repository's on-disk directory spelling.
- `app:app_core_test` is a tiny compiled Java test that exercises the selected
  platform implementation.
- `app:linux_admin_tool`, `app:macos_admin_tool`, and
  `services:linux_admin_bundle` show direct and transitive target
  compatibility.
- `services:service_probe` is the shell version of the same runfiles pattern.
- `tools/bazel` is the Bazelisk hook where a real project would normalize local
  environment before the real Bazel binary runs.

## Try These Commands

```bash
bazel mod graph
bazel build //...
bazel test //app:app_core_test
bazel run //app:maintainer_app
bazel run //services:service_probe
bazel build --config=linux //app:maintainer_app
bazel build --config=macos //services:all
bazel build --config=macos //app:linux_admin_tool
bazel build --announce_rc --config=ci //...
bazel test --config=ci //...
bash tools/ci_bazel.sh //...
bazel canonicalize-flags --for_command=build -- --config=release -c opt
```

The explicit `//app:linux_admin_tool` command is expected to fail under the
macOS target platform. The package wildcard `bazel build --config=macos
//services:all` skips `//services:linux_admin_bundle` because it depends on the
Linux-only admin tool.

Use `bazel run` for the host-compatible target platform. Cross-platform Java
builds compile correctly, but their launcher may point at a remote JDK for the
target OS, which is not executable on a different host.

Stamping is intentionally not part of this project example. It is better covered
by a focused snippet where `--workspace_status_command` output is visible in a
declared build output.
