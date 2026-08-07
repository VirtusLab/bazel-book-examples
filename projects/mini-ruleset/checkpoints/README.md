# Versioned bootstrap checkpoints

The checked-in project remains the finished ruleset. These cumulative overlays
materialize the smaller states used by checkpoints 1–3 of the capstone without
duplicating the whole project. This directory is reproduction and validation
support; the capstone article explains what each checkpoint teaches.

```bash
bash checkpoints/materialize_checkpoint.sh 2 /tmp/rules-glyph-checkpoint2
cd /tmp/rules-glyph-checkpoint2
bazel build //examples/basic:bootstrap
```

Checkpoint 1 writes placeholder outputs, checkpoint 2 replaces that
implementation with the real one-shot Glyph compiler action, and checkpoint 3
switches the BUILD-facing load to the public `//glyph:defs.bzl` facade.

`materialize_checkpoint.sh` copies the finished project without generated Bazel
state or the finished module lockfile, then applies the versioned files under
`overlays/` cumulatively. Requesting checkpoint 3 therefore applies checkpoints
1, 2, and 3 in order. The destination must not already exist.

Run the lightweight targeted check with:

```bash
bash checkpoints/validate_checkpoints.sh
```

The validator builds the bootstrap target in all three materialized workspaces.
It also verifies that checkpoint 3 rejects a consumer that loads the internal
rule implementation instead of the public facade.
