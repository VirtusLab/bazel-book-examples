#!/usr/bin/env python3
"""Prove a real local-registry module update in an isolated workspace copy."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(workspace: Path, output_base: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            shutil.which("bazel") or shutil.which("bazelisk") or "bazel",
            f"--output_base={output_base}",
            *args,
            f"--registry=file://{workspace / 'registry'}",
            "--registry=https://bcr.bazel.build",
        ],
        cwd=workspace,
        check=False,
        capture_output=True,
        text=True,
    )


def require(result: subprocess.CompletedProcess[str], context: str) -> None:
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        raise RuntimeError(context)


def built_message(workspace: Path, output_base: Path) -> str:
    build = run(workspace, output_base, "build", "//app:message")
    require(build, "message build failed")
    info = run(workspace, output_base, "info", "bazel-bin")
    require(info, "bazel-bin lookup failed")
    return (Path(info.stdout.strip()) / "app/resolved-message.txt").read_text().strip()


def main() -> int:
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="registry-update-") as temp:
        workspace = Path(temp) / "workspace"
        shutil.copytree(source, workspace, ignore=shutil.ignore_patterns("bazel-*"))
        output_base = Path(temp) / "output-base"

        before = built_message(workspace, output_base)
        lock_before = (workspace / "MODULE.bazel.lock").read_bytes()

        module_file = workspace / "MODULE.bazel"
        module_file.write_text(module_file.read_text().replace('version = "1.0.0"', 'version = "2.0.0"'))
        graph = run(workspace, output_base, "mod", "graph", "--lockfile_mode=update")
        require(graph, "module update failed")
        after = built_message(workspace, output_base)
        lock_after = (workspace / "MODULE.bazel.lock").read_bytes()

        if before != "resolved through local registry version 1.0.0":
            msg = f"unexpected 1.0.0 output: {before}"
            raise AssertionError(msg)
        if "registry_dep@2.0.0" not in graph.stdout:
            msg = "updated graph does not contain registry_dep@2.0.0"
            raise AssertionError(msg)
        if after != "resolved through local registry version 2.0.0":
            msg = f"unexpected 2.0.0 output: {after}"
            raise AssertionError(msg)
        if lock_before != lock_after:
            msg = "plain local_path module selection unexpectedly changed MODULE.bazel.lock"
            raise AssertionError(msg)

    print("updated registry_dep 1.0.0 -> 2.0.0 and rebuilt changed dependency bytes")
    print("MODULE.bazel.lock stayed unchanged because this update has no extension state")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
