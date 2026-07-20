# Repo Mapping And Runfiles

This snippet keeps the apparent-vs-canonical-name lesson minimal and
runnable. It exists so `3.1.3:RepoMapping` can show readers a working
`$(rlocationpath ...)` lookup, and so `1.1.2:BazelRun` can point at a
runfiles-safe runtime data-read pattern without dragging in a full
project example.

## What the workspace contains

- `MODULE.bazel` declares one module extension that creates a single
  auxiliary repository named `@aux_data` with a one-line text payload.
- `tools/aux_extension.bzl` is the entire extension: a `repository_rule`
  that writes `BUILD.bazel` and `value.txt`, plus a `module_extension`
  that instantiates it once. There is intentionally no tag class — the
  point is repo mapping and runfiles, not extension surface.
- `app/uses_runfiles.sh` is the *correct* pattern. It receives
  `$(rlocationpath @aux_data//:value.txt)` as `args[0]` and resolves it
  through the standard Bazel bash runfiles library
  (`@bazel_tools//tools/bash/runfiles`).
- `app/assumes_canonical_path.sh` is the *wrong* pattern. It only prints
  a warning explaining what would break — it does not actually try to
  read `external/aux_data/value.txt`, because that path is unstable
  under Bzlmod and we want the snippet to be reproducible (`exit 0`)
  instead of flaky.

## Why hard-coding `external/<name>` breaks

Under Bzlmod, repositories live under their *canonical* name in the
output base. The apparent name (`@aux_data` here) is just a label
nickname controlled by the consuming module's repo-mapping table. A
script that stitches together `external/aux_data/value.txt` is silently
relying on three things, all of which are explicitly documented as not
guaranteed:

1. The apparent name happens to equal the canonical name.
2. The canonical name happens to equal the directory name.
3. The directory format does not change between Bazel versions.

`$(rlocationpath ...)` plus a runfiles library replaces all three
assumptions with one stable contract: Bazel hands the binary a runtime
token, and the runfiles library knows how to turn that token into a
concrete file path on this host.

## Try it

```bash
bazel build //app:uses_runfiles
bazel run   //app:uses_runfiles
bazel run   //app:assumes_canonical_path
bazel mod show_repo @aux_data
```

The `uses_runfiles` invocation prints the rlocationpath token, the
resolved on-disk path, and the file payload. The `assumes_canonical_path`
invocation prints the warning text and exits 0. `bazel mod show_repo
@aux_data` shows the apparent-to-canonical mapping for the repo the
extension created.

## What this snippet is *not*

- It is not a full module-extension tutorial — `policy_extension.bzl`
  in `projects/maintainer-workspace` is the richer example with tag
  classes and per-module configuration.
- It is not a benchmark of every runfiles edge case — Windows manifest
  layout and language-specific runfiles libraries are out of scope.
- It does not demonstrate runfiles for tests; that is a different
  contract from `bazel run` for non-test binaries (see `1.1.2:BazelRun`).
