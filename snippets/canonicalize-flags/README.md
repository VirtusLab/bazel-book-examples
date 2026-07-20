# Canonicalize Flags

This snippet pins the exact behavior of `bazel canonicalize-flags` that the
`3.2.4:CommandLineFlags` article quotes: short flags expand, boolean flags
normalize, `--config=ci` survives unexpanded, and command-specific flag
parsing is enforced when `--for_command` is set.

The workspace is intentionally tiny — a single empty `filegroup` and a
`.bazelrc` that defines `build:ci`. The `build:ci` block exists so the second
command has a real named config to leave untouched; it is never expanded by
`canonicalize-flags`, which is the whole point.

## Commands and what they teach

### Short and boolean flag expansion

```none
$ bazel canonicalize-flags -- -c opt -k --define=ENV=prod
--compilation_mode=opt
--keep_going=1
--define=ENV=prod
```

`-c` becomes `--compilation_mode`, `-k` becomes the explicit boolean
`--keep_going=1`, and `--define=ENV=prod` is already canonical so it passes
through. The output is deterministic, which is what makes this command useful
for diffing the effective flag set between two environments.

### `--for_command` and `--config=ci`

```none
$ bazel canonicalize-flags --for_command=test -- --test_output=errors --config=ci
--test_output=errors
--config=ci
```

`--test_output=errors` is recognized because parsing is scoped to the `test`
command. `--config=ci` is **not** expanded into the underlying `--keep_going`,
`--announce_rc`, and `--verbose_failures` defined in `.bazelrc`, even though
those would be the effective flags after rc expansion. Config expansion is
intentionally outside the canonicalization step, because it depends on which
rc files the real invocation will load.

### `--for_command` rejecting an unknown option

```none
$ bazel canonicalize-flags --for_command=version -- --keep_going
ERROR: Unrecognized option: --keep_going
```

The `version` command does not accept `--keep_going`, so canonicalization
fails. This is the article's "options the chosen command does not understand
cause an error" behavior, expressed against a command whose option surface is
much smaller than `build` or `test`.

## Why not show `--for_command=test` rejecting a build-only flag?

The plan originally suggested using `--for_command=test` to reject a
build-only flag. On Bazel 9, `bazel test` inherits the entire `bazel build`
option surface plus its own test-specific flags, so most "build-only" flags
are still accepted under `--for_command=test`. The `--for_command=version`
case above demonstrates the same lesson — command-specific parsing — without
depending on the exact partition between build and test options.
