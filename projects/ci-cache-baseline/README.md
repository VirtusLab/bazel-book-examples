# CI Cache Baseline

This Level 3 project is the smallest concrete shape of a Bazel CI setup: pin a
Bazel version, keep CI-only flags behind `--config=ci`, restore the cache
directories that can survive a runner, run one broad test command, and stop the
Bazel server before the cache is saved.

The CI stage of
[Build a Maintainable Bazel Workspace](../../../conspect/3-maintainer/3.8.1-build-maintainable-bazel-workspace.md)
builds toward this finished setup. This README is the reference map for its CI
and cache files.

## What To Inspect

- `.bazelversion` pins Bazel 9.0.0 so CI and local runs use the same Bazel
  release through Bazelisk.
- `.bazelrc` defines `common:ci`, `build:ci`, and `test:ci`. The config keeps CI
  logs stable with `--announce_rc`, `--color=no`, `--curses=no`,
  `--noshow_progress`, and test output limited to failures.
- `.github/workflows/bazel.yml` uses
  [`bazel-contrib/setup-bazel`](https://github.com/bazel-contrib/setup-bazel) to
  install a pinned Bazelisk, restore the Bazelisk / disk / repository caches,
  and then runs `bash tools/ci_bazel.sh //...`. This is the
  recommended-in-3.6.1 GitHub Actions shape.
- `tools/ci_bazel.sh` is intentionally small: it runs
  `bazel test --config=ci`, prints a short status message, and preserves Bazel's
  exit code for the CI platform.
- `app/BUILD.bazel` has one generated output so the build has an action result
  that can be reused from the disk cache.
- `tests/BUILD.bazel` runs shell tests over both the source file and generated
  output, making `bazel test --config=ci //...` meaningful without extra
  language dependencies.

## Cache Layers

`setup-bazel` and `.bazelrc` work together: the action handles GitHub Actions
restore/save around the build, the `.bazelrc` shows where each cache flag
actually lives in a workspace.

- `~/.cache/bazelisk` stores the Bazelisk-managed Bazel binary. `bazelisk-cache:
  true` plus `bazelisk-version: v1.25.0` keeps the launcher itself stable, so a
  `.bazelversion` change should be the main reason this cache misses.
- `~/.cache/bazel-repo` is the path `--repository_cache` points at in
  `.bazelrc`. It stores fetched external archives so a new runner does not
  download the same dependencies again. This example has no external
  dependencies, but the path is wired the same way a real workspace would wire
  it. `setup-bazel`'s `repository-cache: true` writes the same path on its
  side, so the workspace and action agree.
- `~/.cache/bazel-disk` is what `--disk_cache` points at in `.bazelrc`. It
  stores action results and content-addressed blobs, so later CI runs can
  reuse unchanged actions even when the Bazel server starts cold. `setup-bazel`'s
  `disk-cache: ${{ github.workflow }}` keys the GitHub Actions cache by
  workflow so unrelated workflows do not fight over the same blob set.

The disk and repository caches live outside the workspace. That avoids Bazel 9's
guard against putting repository-cache internals inside the main repo, and it
keeps generated cache data out of source traversal.

## Remote Cache Placeholder

The `.bazelrc` includes commented `--remote_cache` lines, but the runnable
example does not require a server. A real rollout should add the endpoint,
credentials, upload policy, and branch trust rules together. One common starting
point is CI uploading action results while developer machines read from the
remote cache without uploading.

## Try These Commands

```bash
bazel build --config=ci //...
bazel test --config=ci //...
bash tools/ci_bazel.sh //...
bazel shutdown
```

`bazel shutdown` is most useful when the same CI job saves cache directories
after Bazel exits. On a fully ephemeral runner the process would die anyway, but
an explicit shutdown leaves the output base and caches quiescent before the
cache-save step runs.
