#!/usr/bin/env python3
"""Assert that buildfiles(deps(...)) exposes a load-only external .bzl edge."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile

LOAD_REPO = "@load_helper//"


def find_bazel() -> str:
    bazel = shutil.which("bazel") or shutil.which("bazelisk")
    if bazel is None:
        msg = "Neither bazel nor bazelisk was found on PATH"
        raise RuntimeError(msg)
    return bazel


def bazel_query(bazel: str, output_base: str, expression: str) -> str:
    result = subprocess.run(
        [bazel, f"--output_base={output_base}", "query", expression],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        msg = (
            f"bazel query {expression!r} failed with exit code {result.returncode}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
        raise RuntimeError(msg)
    return result.stdout


def shutdown_bazel(bazel: str, output_base: str) -> None:
    subprocess.run(
        [bazel, f"--output_base={output_base}", "shutdown"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def assert_query_edges(bazel: str, output_base: str) -> int:
    deps_output = bazel_query(bazel, output_base, "filter('@', deps(//app:lightweight))")
    if LOAD_REPO in deps_output:
        print("deps() unexpectedly exposed the load-only helper repo:")
        print(deps_output)
        return 1

    buildfiles_output = bazel_query(bazel, output_base, "buildfiles(deps(//app:lightweight))")
    if LOAD_REPO not in buildfiles_output or "defs.bzl" not in buildfiles_output:
        print("buildfiles(deps(...)) did not expose @load_helper//:defs.bzl:")
        print(buildfiles_output)
        return 1

    print("deps() hides the load-only repo; buildfiles(deps(...)) reveals it.")
    return 0


def main() -> int:
    bazel = find_bazel()
    with tempfile.TemporaryDirectory(prefix="bazel-eager-fetch-load-edge-") as output_base:
        try:
            return assert_query_edges(bazel, output_base)
        finally:
            shutdown_bazel(bazel, output_base)


if __name__ == "__main__":
    sys.exit(main())
