"""Tiny module extension that creates an auxiliary repository with one data file.

The repo is intentionally minimal: a single text file plus a `BUILD.bazel`
that exports it. Consumers should reach `value.txt` through runfiles APIs
(or `$(rlocationpath ...)`), not by guessing at `external/<name>` paths.
"""

def _aux_repo_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", "exports_files([\"value.txt\"])\n")
    repository_ctx.file(
        "value.txt",
        "aux_repo_payload=hello-from-aux\n",
    )

_aux_repo = repository_rule(
    implementation = _aux_repo_impl,
)

def _aux_extension_impl(_module_ctx):
    _aux_repo(name = "aux_data")

aux_extension = module_extension(
    implementation = _aux_extension_impl,
)
