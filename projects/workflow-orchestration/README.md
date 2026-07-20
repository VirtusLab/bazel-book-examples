# Workflow Orchestration (Outside the Graph)

Small Level 3 workspace that draws the line between Bazel's declared
outputs and orchestration around Bazel. It contains three deliberately
small pieces:

1. A normal **build target** under `//release:` that produces declared
   files in `bazel-out`.
2. A **`.publish` launcher** that *uses* those build outputs to write
   artifacts back into the workspace under `out/published/`. The launcher is
   invoked with `bazel run`, which is the explicit boundary crossing.
3. A **query-driven workflow** in `tools/run_release_targets.sh` that asks
   Bazel for every target tagged `release`, then feeds those labels back to
   `bazel build`.

The conspect articles that point here are `3.7.1:BazelScope` and
`3.7.2:WorkflowPatterns`; `3.7.3:AXL` references the same shape as the
shell-script form of an outside-the-graph workflow.

## Inside Bazel's output boundary

These targets fit Bazel's contract: declared inputs, declared outputs, no
side effects on the source tree.

- `//release:notes` (`genrule`) writes `release_notes.txt` under
  `bazel-bin/release/`.
- `//release:summary` (`genrule`) writes `release_summary.txt` under
  `bazel-bin/release/`.
- Both targets carry `tags = ["release"]` so the query-driven workflow can
  discover them without a hand-maintained list.

```bash
bazel build //release:notes
bazel build //release:summary
```

After a successful build, the convenience symlink view is the usual one:

```text
bazel-bin/release/release_notes.txt
bazel-bin/release/release_summary.txt
```

Nothing here mutates the source tree. Reanalyzing or rebuilding a second
time produces the same files.

## Around Bazel

These steps sit *next to* Bazel. They still talk to it (build outputs,
query results), but their results are not declared Bazel outputs.

### `bazel run //release:notes.publish`

The `notes.publish` `sh_binary` takes both `:notes` and `:summary` through
`data` + `$(rlocationpath ...)`. When run with `bazel run`, Bazel sets
`BUILD_WORKSPACE_DIRECTORY` to this workspace; the launcher copies the
artifacts into `${BUILD_WORKSPACE_DIRECTORY}/out/published/` and writes a
small `PUBLISHED.txt` manifest beside them.

```bash
bazel run //release:notes.publish
ls out/published/
# PUBLISHED.txt
# release_notes.txt
# release_summary.txt
```

Two important properties:

- **Outside Bazel's output boundary.** `out/published/` is *not* under
  `bazel-out`. Bazel does not track it, does not cache it, and does not know
  whether it is current. Treat the publish step as a workflow operation, not
  as a build action.
- **Idempotent.** The launcher scrubs `out/published/` before copying, so
  re-running `bazel run //release:notes.publish` yields the same tree. The
  workspace stays git-clean because `out/` is in `.gitignore`.

### `tools/run_release_targets.sh`

A pure shell wrapper: it runs `bazel query` to collect release-tagged
labels, then hands those labels back to `bazel build`. There is no
`//:all_release` collector target on purpose — the query keeps target
selection cheap and avoids the whole-repo load that a synthetic collector
target would force.

```bash
./tools/run_release_targets.sh
```

The query is `attr("tags", "\brelease\b", kind(".* rule", //...))`. Adding a
new release artifact is a one-line change: tag the new target `release` and
the next script run picks it up.

## Try it end-to-end

```bash
bazel build //release:notes
bazel run //release:notes.publish
./tools/run_release_targets.sh
ls out/published/
```

The first line stays inside Bazel's contract. The second line crosses the
boundary explicitly. The third line is orchestration around Bazel: it asks
Bazel two separate questions ("which labels?" and then "build these") rather
than collapsing them into one fake target.

The four files that matter are:

- `release/BUILD.bazel` — the declared build targets and the `.publish`
  launcher target.
- `release/publish_notes.sh` — the side-effecting launcher.
- `tools/run_release_targets.sh` — the query-driven workflow.
- `MODULE.bazel` — Bzlmod entry pulling in `rules_shell` for `sh_binary`.

The point of the example is the boundary, not the volume of code: a real
release workflow looks the same shape, just with bigger artifacts and more
release-tagged targets.
