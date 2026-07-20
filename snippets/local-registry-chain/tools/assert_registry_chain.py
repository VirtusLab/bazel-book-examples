#!/usr/bin/env python3
"""Assert that a local registry chain resolves the sample module."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def find_bazel() -> str:
    bazel = shutil.which("bazel") or shutil.which("bazelisk")
    if bazel is None:
        msg = "Neither bazel nor bazelisk was found on PATH"
        raise RuntimeError(msg)
    return bazel


def run_bazel(bazel: str, output_base: str, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [bazel, f"--output_base={output_base}", *args],
        check=False,
        capture_output=True,
        text=True,
    )


def main() -> int:
    bazel = find_bazel()
    registry_url = f"file://{Path.cwd() / 'registry'}"
    with tempfile.TemporaryDirectory(prefix="bazel-local-registry-chain-") as output_base:
        graph = run_bazel(
            bazel,
            output_base,
            "mod",
            "graph",
            f"--registry={registry_url}",
            "--registry=https://bcr.bazel.build",
        )
        if graph.returncode != 0:
            print(graph.stdout)
            print(graph.stderr, file=sys.stderr)
            return graph.returncode
        if "registry_dep@1.0.0" not in graph.stdout:
            print("Expected registry_dep@1.0.0 in bazel mod graph output:")
            print(graph.stdout)
            return 1

        build = run_bazel(
            bazel,
            output_base,
            "build",
            f"--registry={registry_url}",
            "--registry=https://bcr.bazel.build",
            "//app:uses_registry_dep",
        )
        if build.returncode != 0:
            print(build.stdout)
            print(build.stderr, file=sys.stderr)
            return build.returncode

        run_bazel(bazel, output_base, "shutdown")

    print("resolved registry_dep@1.0.0 with the local registry first and BCR configured as fallback")
    return 0


if __name__ == "__main__":
    sys.exit(main())
