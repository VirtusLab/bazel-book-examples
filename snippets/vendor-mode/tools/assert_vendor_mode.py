#!/usr/bin/env python3
"""Exercise bazel vendor against a local archive-backed registry entry."""

from __future__ import annotations

import base64
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


def find_bazel() -> str:
    bazel = shutil.which("bazel") or shutil.which("bazelisk")
    if bazel is None:
        msg = "Neither bazel nor bazelisk was found on PATH"
        raise RuntimeError(msg)
    return bazel


def reset_dir(path: Path) -> None:
    shutil.rmtree(path, ignore_errors=True)
    path.mkdir(parents=True)


def create_archive(workspace: Path) -> Path:
    dist = workspace / "dist"
    reset_dir(dist)
    archive = dist / "vendored_dep-1.0.0.tar.gz"
    source_root = workspace / "sources" / "vendored_dep"

    with tarfile.open(archive, "w:gz") as tar:
        for path in sorted(source_root.rglob("*")):
            arcname = Path("vendored_dep") / path.relative_to(source_root)
            info = tar.gettarinfo(path, arcname.as_posix())
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            info.mtime = 0
            if path.is_file():
                with path.open("rb") as f:
                    tar.addfile(info, f)
            else:
                tar.addfile(info)

    return archive


def sri_sha256(path: Path) -> str:
    digest = hashlib.sha256(path.read_bytes()).digest()
    return "sha256-" + base64.b64encode(digest).decode("ascii")


def create_runtime_registry(workspace: Path, archive: Path) -> Path:
    runtime_registry = workspace / ".generated-registry"
    shutil.rmtree(runtime_registry, ignore_errors=True)
    shutil.copytree(workspace / "registry_template", runtime_registry)

    source_json = runtime_registry / "modules" / "vendored_dep" / "1.0.0" / "source.json"
    source_json.write_text(
        json.dumps(
            {
                "type": "archive",
                "url": archive.resolve().as_uri(),
                "integrity": sri_sha256(archive),
                "strip_prefix": "vendored_dep",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return runtime_registry


def run(command: list[str], workspace: Path) -> None:
    result = subprocess.run(command, cwd=workspace, check=False, text=True)
    if result.returncode != 0:
        msg = f"{' '.join(command)} failed with exit code {result.returncode}"
        raise RuntimeError(msg)


def assert_vendored_source(vendor_dir: Path) -> None:
    matches = [
        path
        for path in vendor_dir.rglob("message.txt")
        if path.read_text(encoding="utf-8").strip() == "copied by bazel vendor"
    ]
    if not matches:
        msg = "vendor_src does not contain vendored_dep/message.txt"
        raise RuntimeError(msg)


def main() -> int:
    workspace = Path.cwd()
    bazel = find_bazel()
    archive = create_archive(workspace)
    runtime_registry = create_runtime_registry(workspace, archive)
    vendor_dir = workspace / "vendor_src"
    shutil.rmtree(vendor_dir, ignore_errors=True)

    registry_url = runtime_registry.resolve().as_uri()
    with tempfile.TemporaryDirectory(prefix="bazel-vendor-source-") as source_output_base:
        run(
            [
                bazel,
                f"--output_base={source_output_base}",
                "vendor",
                "--vendor_dir=vendor_src",
                f"--registry={registry_url}",
                "--registry=https://bcr.bazel.build",
                "//app:uses_vendored_dep",
            ],
            workspace,
        )

    if not (vendor_dir / "VENDOR.bazel").is_file():
        msg = "bazel vendor did not create vendor_src/VENDOR.bazel"
        raise RuntimeError(msg)
    if not (vendor_dir / "_registries").is_dir():
        msg = "bazel vendor did not create vendor_src/_registries"
        raise RuntimeError(msg)
    assert_vendored_source(vendor_dir)

    shutil.rmtree(workspace / "dist")

    with (
        tempfile.TemporaryDirectory(prefix="bazel-vendor-verify-") as verify_output_base,
        tempfile.TemporaryDirectory(prefix="bazel-vendor-empty-cache-") as empty_cache,
    ):
        run(
            [
                bazel,
                f"--output_base={verify_output_base}",
                "build",
                "--vendor_dir=vendor_src",
                f"--repository_cache={empty_cache}",
                f"--registry={registry_url}",
                "--registry=https://bcr.bazel.build",
                "//app:uses_vendored_dep",
            ],
            workspace,
        )

    print("fresh build resolved the removed dependency archive from vendor_src")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
