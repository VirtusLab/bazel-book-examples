# Local Registry Chain

This snippet uses a tiny local index registry so the registry layout and
`--registry=file://...` command line can be inspected without depending on the
public Bazel Central Registry.

The root module depends on `registry_dep` at version `1.0.0`. Bazel resolves
that module through `registry/modules/registry_dep/1.0.0/MODULE.bazel`, then
materializes its source from the local path recorded in `source.json`.
