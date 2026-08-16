# CI Cache Baseline

This project is the smallest concrete shape of a Bazel CI setup: pin a Bazel
version, keep CI-only flags behind `--config=ci`, restore the cache directories
that can survive a runner, run one broad test command, and stop the Bazel server
before the cache is saved. It also includes a live shared-cache experiment for
Level 6: one clean Bazel client uploads an action result and a second clean
client reuses it without executing the action locally.

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
- `tools/prove_shared_remote_cache.sh` provisions the pinned cache backend and
  verifies its release checksum.
- `tests/remote_cache_proof_test.sh` owns the live assertions over both client
  execution logs and the backend access log.

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

## Prove a Shared Remote Cache

On upstream-supported Ubuntu 20.04 or later, or macOS 13 or later, with an
amd64 or arm64 host, Bazelisk, `curl`, and internet access for the first
download, run:

```bash
bash tools/prove_shared_remote_cache.sh
```

The launcher selects the amd64 or arm64 release of `bazel-remote` 2.6.1 for
those published host bounds, downloads it from the project's GitHub release,
and verifies its published SHA-256 digest. The verified binary is reused from
`bazel-cache-tools/`, which is covered by this workspace's `bazel-*` ignore
rule. The fixture does not claim support for other Linux distributions or older
operating-system releases.

The proof then performs three builds of the existing
`//app:uppercase_message` genrule:

1. Client A gets an empty output base and an empty backend. Its execution log
   must say `cacheHit=false` with a local runner. The backend log must record an
   AC `GET 404`, successful CAS writes, and an AC write.
2. Client B gets a different empty output base and sets
   `--remote_upload_local_results=false`. Its execution log must contain the
   same action and output digests as A, `cacheHit=true`, and
   `runner="remote cache hit"`. The backend must serve that AC entry and output
   CAS blob with `GET 200` responses.
3. The bypass client gets a third empty output base and a second, empty backend
   with `--remote_upload_local_results=false`. The lookup must miss, the backend
   must receive no writes, and the action must return to `cacheHit=false` and a
   local runner. This control preserves a comparable action digest while ruling
   out a warm Bazel server, output tree, or local action cache as the explanation
   for B's result.

A successful Linux x86_64 run with Bazel 9.0.0 ends in this shape (the digest
can differ with platform or tool inputs):

```text
SHARED REMOTE CACHE PROOF PASSED
client A: action 3bf8672d...715d92, runner 'processwrapper-sandbox', cacheHit=false
backend: AC miss -> AC/CAS writes -> AC/CAS reads for the same digests
client B: action 3bf8672d...715d92, runner 'remote cache hit', cacheHit=true
bypass:   runner 'processwrapper-sandbox', cacheHit=false (empty backend, uploads disabled)
```

The test exits nonzero if any leg is missing, if the clients report different
digests, or if the backend log cannot join the miss, writes, and reads. On a
failure it retains the temporary execution and access logs and prints their
directory; on success it shuts down all three Bazel servers and the backend and
removes the temporary state.

This is deliberately a loopback HTTP fixture. It proves cache mechanics and
cross-client isolation, not production security. A real rollout still needs a
TLS endpoint, authenticated reader and writer identities, independently
enforced write policy, bounded persistent storage, observability, and branch or
tenant trust boundaries.

## Try These Commands

```bash
bazel build --symlink_prefix=/ --lockfile_mode=off --config=ci //...
bazel test --symlink_prefix=/ --lockfile_mode=off --config=ci //...
bash tools/ci_bazel.sh //...
bash tools/prove_shared_remote_cache.sh
bazel shutdown
```

`bazel shutdown` is most useful when the same CI job saves cache directories
after Bazel exits. On a fully ephemeral runner the process would die anyway, but
an explicit shutdown leaves the output base and caches quiescent before the
cache-save step runs.
