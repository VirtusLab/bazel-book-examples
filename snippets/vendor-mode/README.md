# Vendor Mode

This snippet vendors a dependency from a tiny local index registry. The
assertion script creates a local source archive, writes a runtime `source.json`
with a `file://` URL and integrity hash, then runs `bazel vendor`. BCR is
configured during this preparation step for Bazel's own tooling modules.

The assertion then removes the source archive and builds with a fresh output
base and an empty repository cache. The small `file://` registry
remains available for module resolution; the dependency source itself can only
come from `vendor_src`, not a previous output base, repository cache, or archive.
