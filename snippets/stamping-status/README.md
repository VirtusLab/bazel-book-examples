# Stamping Status

This snippet measures the cache boundary created by workspace-status files:

- `status/stable.txt` and `status/volatile.txt` are independent, controllable
  inputs to `tools/workspace_status.sh`.
- `app/versioned.bzl` deliberately declares `ctx.info_file` and
  `ctx.version_file` as inputs. This custom experiment rule always consumes
  both files; it does not model a language rule's `stamp` attribute or make
  `--stamp` control that consumption.
- `tools/run_cache_experiment.sh` uses a fresh output base and one execution log
  per build to prove whether the `StampedReport` action ran.

Run `bash tools/run_cache_experiment.sh`. It changes volatile status, stable
status, and an ordinary declared input in turn. The script also checks output
bytes, demonstrating that a volatile-only update can remain stale until another
real input makes the action execute.
