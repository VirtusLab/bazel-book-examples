# Local Registry Chain

This snippet uses a tiny local index registry so the registry layout and
`--registry=file://...` command line can be inspected without depending on the
public Bazel Central Registry.

The root module depends on `registry_dep` at version `1.0.0`. Bazel resolves
that module through `registry/modules/registry_dep/1.0.0/MODULE.bazel`, then
materializes its source from the local path recorded in `source.json`.

## Perform a real dependency update

The registry also contains `registry_dep@2.0.0` with different source bytes.
Run the update proof from this directory:

```bash
python3 tools/assert_dependency_update.py
```

The script copies the workspace to a temporary directory, builds the 1.0.0
dependency, changes the real `bazel_dep()` declaration to 2.0.0, runs
`bazel mod graph --lockfile_mode=update`, and rebuilds the consumer. It verifies
both the selected module version and the changed output bytes. The original
workspace remains untouched.

This plain `local_path` module has no module-extension state, so its version
change does not alter `MODULE.bazel.lock`. That unchanged file is an observed
result, not a reason for update automation to skip lockfile regeneration: an
integration using extensions must retain and review whatever state its actual
resolution updates.
