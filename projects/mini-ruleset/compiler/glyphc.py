#!/usr/bin/env python3
"""Tiny compiler/linker for the teaching-only Glyph language."""

from __future__ import annotations

import argparse
import shlex
import stat
from pathlib import Path
from typing import cast


def parse_source(path: Path) -> dict[str, object]:
    module = None
    imports: list[str] = []
    messages: list[str] = []
    resources: list[str] = []
    entry = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("module "):
            module = line.removeprefix("module ").strip()
        elif line.startswith("import "):
            imports.append(line.removeprefix("import ").strip())
        elif line.startswith("message "):
            messages.append(line.removeprefix("message ").strip().strip('"'))
        elif line.startswith("resource "):
            resources.append(line.removeprefix("resource ").strip())
        elif line.startswith("entry "):
            entry = line.removeprefix("entry ").strip()
        else:
            msg = f"{path}: unknown Glyph directive: {line}"
            raise SystemExit(msg)

    if not module:
        msg = f"{path}: missing 'module <name>' declaration"
        raise SystemExit(msg)
    return {
        "module": module,
        "imports": imports,
        "messages": messages,
        "resources": resources,
        "entry": entry or "",
    }


def read_interface(path: Path) -> str:
    """Return the single module name recorded in a Glyph interface object.

    Interface objects are deliberately tiny: one `module=<name>` line. That is
    all a dependent needs to resolve imports, which is why compiling reads the
    interface objects (GlyphInfo.interface_objects) rather than the full link
    objects — the ijar/header-jar idea in miniature.
    """
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        key, _, value = raw_line.partition("=")
        if key == "module":
            return value
    msg = f"{path}: interface object is missing a module name"
    raise SystemExit(msg)


def read_object(path: Path) -> dict[str, object]:
    imports: list[str] = []
    messages: list[str] = []
    resources: list[str] = []
    resource_paths: dict[str, str] = {}
    data: dict[str, object] = {
        "imports": imports,
        "messages": messages,
        "resources": resources,
        "resource_paths": resource_paths,
    }
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        key, _, value = raw_line.partition("=")
        if key == "import":
            imports.append(value)
        elif key == "message":
            messages.append(value)
        elif key == "resource":
            resources.append(value)
        elif key == "resource_path":
            logical_path, separator, runfiles_path = value.partition("\t")
            if not separator:
                msg = f"{path}: malformed resource_path entry"
                raise SystemExit(msg)
            resource_paths[logical_path] = runfiles_path
        else:
            data[key] = value
    return data


def logical_resource_path(short_path: str) -> str:
    """Strip Bazel's external-repository prefix from a File.short_path."""
    if short_path.startswith("../"):
        _, _, repository_relative = short_path.partition("/")
        _, _, repository_relative = repository_relative.partition("/")
        return repository_relative
    return short_path


def compile_sources(args: argparse.Namespace) -> None:
    sources = [parse_source(Path(src)) for src in args.src]
    modules = {str(src["module"]) for src in sources}
    if len(modules) != 1:
        msg = "glyph_library examples keep one module per target"
        raise SystemExit(msg)
    module = modules.pop()
    if module != args.module:
        msg = f"{args.module}: BUILD module attr does not match source module {module}"
        raise SystemExit(msg)

    # Visible modules are discovered by reading the interface objects of the
    # direct deps/exports (and everything they re-export), not from a list of
    # strings on the command line. Reading them here is what makes
    # GlyphInfo.interface_objects a load-bearing input instead of a file that is
    # merely staged and ignored.
    visible_modules = {read_interface(Path(path)) for path in args.dep_iface}
    declared_resource_paths = {logical_resource_path(runfiles_path): runfiles_path for runfiles_path in args.resource}
    declared_resources = set(declared_resource_paths)
    for source in sources:
        for imported in cast("list[str]", source["imports"]):
            if imported not in visible_modules:
                msg = f"{module}: import '{imported}' is missing from deps"
                raise SystemExit(msg)
        for resource in cast("list[str]", source["resources"]):
            if resource not in declared_resources:
                msg = f"{module}: resource '{resource}' is missing from data"
                raise SystemExit(msg)

    out = Path(args.out)
    iface = Path(args.iface)
    manifest = Path(args.manifest)
    for path in (out, iface, manifest):
        path.parent.mkdir(parents=True, exist_ok=True)

    # The interface object carries only this module's name. Dependents read it
    # (never the full link object) to resolve imports, and the transitive set is
    # assembled by GlyphInfo.interface_objects rather than by fattening this file.
    iface.write_text(f"module={module}\n", encoding="utf-8")

    lines = [f"module={module}", f"mode={args.mode}", f"target_os={args.target_os}"]
    used_resources: set[str] = set()
    for source in sources:
        lines.extend(f"import={imported}" for imported in cast("list[str]", source["imports"]))
        lines.extend(f"message={message}" for message in cast("list[str]", source["messages"]))
        source_resources = cast("list[str]", source["resources"])
        used_resources.update(source_resources)
        lines.extend(f"resource={resource}" for resource in source_resources)
        if source["entry"]:
            lines.append(f"entry={source['entry']}")
    lines.extend(
        f"resource_path={resource}\t{declared_resource_paths[resource]}" for resource in sorted(used_resources)
    )
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    manifest.write_text(
        "\n".join(
            [
                f"module: {module}",
                f"mode: {args.mode}",
                f"target_os: {args.target_os}",
                "exports:",
                *[f"  - {exported}" for exported in sorted(set(args.exported_module))],
                "deps:",
                *[f"  - {dep}" for dep in sorted(visible_modules)],
                "resources:",
                *[f"  - {resource}" for resource in sorted(declared_resources)],
            ],
        )
        + "\n",
        encoding="utf-8",
    )


def link_binary(args: argparse.Namespace) -> None:
    objects = [read_object(Path(obj)) for obj in args.object]
    modules = {str(obj["module"]) for obj in objects}
    if args.main not in modules:
        msg = f"main module {args.main} is not present in linked objects"
        raise SystemExit(msg)

    messages: list[str] = []
    resources: set[str] = set()
    resource_paths: dict[str, str] = {}
    for obj in objects:
        messages.extend(cast("list[str]", obj.get("messages", [])))
        resources.update(cast("list[str]", obj.get("resources", [])))
        resource_paths.update(cast("dict[str, str]", obj.get("resource_paths", {})))

    script = Path(args.out)
    script.parent.mkdir(parents=True, exist_ok=True)
    # Locate our own runfiles to read resource data. These two lines are the
    # same convention the rule-generated launchers emit via
    # glyph_runfiles_preamble() in glyph/internal/runfiles.bzl; they are repeated
    # here because the compiler is a separate program and cannot load Starlark.
    # Keep them in lockstep with that helper. (A production ruleset would source
    # @bazel_tools//tools/bash/runfiles instead of hand-rolling the lookup.)
    body = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        'runfiles_root="${RUNFILES_DIR:-${TEST_SRCDIR:-$0.runfiles}}"',
        f'workspace="${{TEST_WORKSPACE:-{args.workspace_name}}}"',
        f"echo 'Glyph binary main={args.main} mode={args.mode} target_os={args.target_os}'",
    ]
    body.extend(f"echo {message!r}" for message in messages)
    for resource in sorted(resources):
        quoted_resource = shlex.quote(resource)
        runfiles_path = resource_paths.get(resource, resource)
        if runfiles_path.startswith("../"):
            resolved_path = f"$runfiles_root/{runfiles_path.removeprefix('../')}"
        else:
            resolved_path = f"$runfiles_root/$workspace/{runfiles_path}"
        body.extend(
            [
                f"resource={quoted_resource}",
                f'path="{resolved_path}"',
                'if [[ ! -f "$path" ]]; then',
                '  echo "missing Glyph resource: $resource" >&2',
                "  exit 1",
                "fi",
                'printf "resource %s: " "$resource"',
                'cat "$path"',
            ],
        )
    script.write_text("\n".join(body) + "\n", encoding="utf-8")
    script.chmod(script.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def write_report(args: argparse.Namespace) -> None:
    modules = sorted(str(read_object(Path(obj))["module"]) for obj in args.object)
    Path(args.out).write_text("\n".join(modules) + "\n", encoding="utf-8")


def validate_object(args: argparse.Namespace) -> None:
    """Check a compiled object and fail on a malformed module.

    This backs the rule's _validation output group: it is a real check that can
    exit non-zero, not a marker file written unconditionally.
    """
    data = read_object(Path(args.object))
    module = str(data.get("module", ""))
    problems: list[str] = []
    if not module:
        problems.append("compiled object is missing a module name")
    elif "." not in module:
        problems.append(
            f"module name {module!r} is not namespaced; expected '<namespace>.<name>'",
        )
    if problems:
        raise SystemExit("; ".join(problems))
    Path(args.out).write_text(f"validated {module}\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subcommands = parser.add_subparsers(dest="command", required=True)

    compile_parser = subcommands.add_parser("compile")
    compile_parser.add_argument("--module", required=True)
    compile_parser.add_argument("--src", action="append", required=True)
    compile_parser.add_argument("--dep_iface", action="append", default=[])
    compile_parser.add_argument("--exported_module", action="append", default=[])
    compile_parser.add_argument("--resource", action="append", default=[])
    compile_parser.add_argument("--mode", required=True)
    compile_parser.add_argument("--target_os", required=True)
    compile_parser.add_argument("--out", required=True)
    compile_parser.add_argument("--iface", required=True)
    compile_parser.add_argument("--manifest", required=True)
    compile_parser.set_defaults(func=compile_sources)

    link_parser = subcommands.add_parser("link")
    link_parser.add_argument("--main", required=True)
    link_parser.add_argument("--object", action="append", required=True)
    link_parser.add_argument("--mode", required=True)
    link_parser.add_argument("--target_os", required=True)
    link_parser.add_argument("--workspace_name", required=True)
    link_parser.add_argument("--out", required=True)
    link_parser.set_defaults(func=link_binary)

    report_parser = subcommands.add_parser("report")
    report_parser.add_argument("--object", action="append", required=True)
    report_parser.add_argument("--out", required=True)
    report_parser.set_defaults(func=write_report)

    validate_parser = subcommands.add_parser("validate")
    validate_parser.add_argument("--object", required=True)
    validate_parser.add_argument("--out", required=True)
    validate_parser.set_defaults(func=validate_object)

    return parser


def run(arguments: list[str] | None = None) -> None:
    """Parse one command line and dispatch it.

    This is the whole public surface of the compiler: pass argv-style arguments
    (or None to read sys.argv) and it runs exactly one compile/link/report/
    validate command. This dispatcher knows nothing about workers, the worker
    protocol, or @flagfiles. Bazel-specific path data enters only as ordinary
    CLI values: the link subcommand receives the workspace name and recorded
    runfiles paths needed to emit a runnable launcher. The persistent-worker
    adapter in glyph/worker imports this module and calls run() per request.
    """
    args = build_parser().parse_args(arguments)
    args.func(args)


def main() -> int:
    run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
