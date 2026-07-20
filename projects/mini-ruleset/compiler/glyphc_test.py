from __future__ import annotations

import argparse
import tempfile
import unittest
from pathlib import Path

import glyphc


class ExternalResourcePathTest(unittest.TestCase):
    def test_external_repo_resource_keeps_logical_name_and_runfiles_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "core.glyph"
            obj = root / "core.glyphobj"
            source.write_text(
                "module app.core\nresource examples/basic/runtime/greeting.txt" + "\n",
                encoding="utf-8",
            )

            glyphc.compile_sources(
                argparse.Namespace(
                    src=[str(source)],
                    module="app.core",
                    dep_iface=[],
                    exported_module=[],
                    resource=["../rules_glyph+/examples/basic/runtime/greeting.txt"],
                    mode="opt",
                    target_os="host",
                    out=str(obj),
                    iface=str(root / "core.glyphiface"),
                    manifest=str(root / "core.glyphmanifest"),
                )
            )

            executable = root / "hello"
            glyphc.link_binary(
                argparse.Namespace(
                    object=[str(obj)],
                    main="app.core",
                    mode="opt",
                    target_os="host",
                    workspace_name="rules_glyph",
                    out=str(executable),
                )
            )

            script = executable.read_text(encoding="utf-8")
            assert "resource=examples/basic/runtime/greeting.txt" in script
            assert 'path="$runfiles_root/rules_glyph+/examples/basic/runtime/greeting.txt"' in script


if __name__ == "__main__":
    unittest.main()
