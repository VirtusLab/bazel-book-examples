# Bazelrc Layering

This snippet keeps rc-file precedence and named-config expansion small enough
to inspect by hand. It exists because {{3.2.1:BazelrcHierarchy}} and
{{3.6.3:CIFlags}} both quote behavior that comes out of a real `.bazelrc`
plus a real `bazel build --announce_rc` invocation; the `maintainer-workspace`
project has the same pattern in a fuller setting, but the noise of multiple
named configs and platform overlays is exactly what this snippet strips out.

## Layout

- `.bazelrc` — one `common` line, a `build:ci` / `test:ci` named config,
  and a final `try-import %workspace%/user.bazelrc`.
- `user.bazelrc.example` — what a developer can copy locally to override
  workspace defaults; `user.bazelrc` itself is git-ignored.
- `app/BUILD.bazel` — a single empty `filegroup(name = "app")` so the
  commands resolve a real label without dragging in toolchains.
- `tools/assert_announce_rc.sh` — captures `--announce_rc` output and
  asserts that the workspace `.bazelrc` path appears in it.

## File-vs-line precedence

Bazel applies two hierarchies at once: rc files have an order, and lines
inside one file have a specificity order.

The file order is the system rc, the workspace `.bazelrc` next to the
repository root marker, the home rc, paths from the `BAZELRC` env var, and
files passed with repeated `--bazelrc=` startup flags. Later files override
earlier ones, and explicit command-line flags override everything from rc
files.

Inside one file, line specificity matters. Each line starts with a scope
such as `common`, `build`, `test`, or a named config like `build:ci`.
`common` applies to every command that understands the flag. Command-scoped
lines are more specific, and inheritance matters: `test` inherits from
`build`, so a `test:ci` line for a flag only `bazel test` understands sits
correctly under `test:ci` rather than `build:ci`.

The `.bazelrc` here intentionally uses both layers:

- `common --color=yes` is a global default that applies to every command
  that understands `--color`.
- `build:ci --keep_going`, `build:ci --noshow_progress`,
  `build:ci --color=no`, `build:ci --curses=no` define the CI build
  posture. None of these apply until `--config=ci` is in effect — for
  example, `bazel build --config=ci //app:app` switches `--color` from
  `yes` to `no` because the named-config line is more specific than the
  unconditional `common` line, and a more-specific match wins.
- `test:ci --test_output=errors` is the test-only flag the CI named
  config adds.

## `try-import` and `user.bazelrc`

The last line of `.bazelrc` is:

```text
try-import %workspace%/user.bazelrc
```

`try-import` is the same as `import`, except a missing file is silently
ignored. That is exactly what makes it the right primitive for a personal
overrides file: the workspace `.bazelrc` works for a fresh checkout where
no `user.bazelrc` exists, and a developer who copies
`user.bazelrc.example` to `user.bazelrc` adds their lines without
committing the result. Imported files take effect at the import point, so
anything inside the imported `user.bazelrc` overrides earlier lines in the
workspace `.bazelrc` for the same flag.

## What `--announce_rc` prints

`bazel build --announce_rc --config=ci //app:app` is the diagnostic
command for "where did this flag come from?". Bazel prints something like:

```text
INFO: Reading 'startup' options from /path/to/snippet/.bazelrc:
INFO: Reading rc options for 'build' from /path/to/snippet/.bazelrc:
  Inherited 'common' options: --color=yes
INFO: Reading rc options for 'build' from /path/to/snippet/.bazelrc:
  'build' options: --keep_going --noshow_progress --color=no --curses=no (with --config=ci)
```

The exact wording shifts between Bazel versions, but the contract is
stable: every rc file Bazel loaded is named, and the flags each one
contributed (including those gated behind `--config=ci`) are reported.
`tools/assert_announce_rc.sh` pins this behavior by asserting that the
workspace `.bazelrc` path appears in the captured output.

## Clean-room: `--ignore_all_rc_files`

`bazel --ignore_all_rc_files build //app:app` skips every rc file: the
system rc, the workspace `.bazelrc`, the home rc, anything from
`BAZELRC`, and any `--bazelrc=` flags. Notice the position:
`--ignore_all_rc_files` is a startup option, so it sits *before* the
command, not after; placing it after the command yields
`Unrecognized option: --ignore_all_rc_files`.

Nothing from this snippet's `.bazelrc` applies under that flag, which is
why `--config=ci` cannot be used in the same invocation: the named
config is not defined when no rc file is loaded. This is the right
primitive when a CI failure looks like a defaulted-flag problem — strip
rc files, add only what the bug needs, and reintroduce layers one at a
time.

## Comparison with `projects/maintainer-workspace`

The maintainer-workspace project uses the same `try-import` pattern and a
larger named-config block (CI defaults, release knobs, platform overlays).
This snippet is deliberately smaller: one named config, one trivial
target, one assertion script, and a README focused on RC-precedence and
`--announce_rc`. Use the project example to see the pattern at workspace
scale; use this snippet to verify exactly what `--announce_rc` and
`--ignore_all_rc_files` print and skip.
