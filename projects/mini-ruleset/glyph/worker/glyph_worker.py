#!/usr/bin/env python3
"""Bazel persistent-worker adapter around the Glyph compiler.

This wrapper belongs to the ruleset, not to the compiler. `glyphc` is a plain,
one-command CLI; it accepts paths and a workspace name as data, while this
adapter is the piece that speaks Bazel's persistent-worker protocol and calls
the compiler as a library. That mirrors how
real rulesets ship workers (Bazel's own JavaBuilder wraps `javac`, rules_kotlin
wraps `kotlinc`, rules_scala wraps `scalac`) instead of teaching every compiler
to understand `--persistent_worker`.

This adapter uses the protobuf protocol (`requires-worker-protocol: proto`),
which is Bazel's default. WorkRequest/WorkResponse messages are exchanged as
length-delimited protobuf: each message on stdin/stdout is prefixed with its
size encoded as a base-128 varint. That framing is why we read/write raw bytes
and manage the varint ourselves — Python's protobuf runtime does not ship a
stream reader for delimited messages.

The adapter handles both shapes of invocation Bazel may use in a single build:

  * Worker strategy on: Bazel starts this process once with `--persistent_worker`
    (it appends the flag itself) and then streams one WorkRequest per compile on
    stdin, keeping the interpreter warm.
  * Worker strategy off (`--strategy=GlyphCompile=local`): Bazel runs this same
    executable as a normal one-shot action, handing it the `@flagfile` it would
    otherwise have turned into a WorkRequest. We expand that file and call the
    compiler once.
"""

from __future__ import annotations

import contextlib
import io
import sys
from pathlib import Path
from typing import BinaryIO

# Both imports resolve through Bazel's runfiles layout: `glyphc` is the compiler
# library and `worker_protocol_pb2` is official protoc output guarded by the
# maintainer-only regeneration check. Keep suppressions local to this binary.
import glyphc  # pyright: ignore[reportMissingImports]
from glyph.worker import worker_protocol_pb2  # pyright: ignore[reportAttributeAccessIssue]


def _expand_flagfiles(arguments: list[str]) -> list[str]:
    """Expand any leading-@ flagfile arguments into their lines.

    In worker mode Bazel has already expanded the flagfile into request
    arguments, so this is a no-op there. In the one-shot fallback Bazel passes a
    literal `@flagfile`, and expanding it here keeps the @-convention a Bazel
    concern rather than leaking into the compiler. The rule writes the file in
    "multiline" format (one argument per line).
    """
    expanded: list[str] = []
    for arg in arguments:
        if arg.startswith("@"):
            text = Path(arg[1:]).read_text(encoding="utf-8")
            expanded.extend(line for line in text.splitlines() if line)
        else:
            expanded.append(arg)
    return expanded


def _run_compiler(arguments: list[str]) -> tuple[int, str]:
    """Run one request's arguments through the compiler and capture the result.

    stdout is reserved for WorkResponses, so the compiler's own output (argparse
    usage errors, SystemExit messages from malformed Glyph sources) is captured
    and returned as the response text instead of corrupting the protocol stream.
    Any failure becomes a nonzero exit code rather than killing the long-lived
    worker process.
    """
    captured = io.StringIO()
    exit_code = 0
    try:
        with contextlib.redirect_stdout(captured), contextlib.redirect_stderr(captured):
            glyphc.run(_expand_flagfiles(arguments))
    except SystemExit as exc:
        code = exc.code
        if isinstance(code, int):
            exit_code = code
        else:
            exit_code = 1
            if code is not None:
                message = str(code)
                captured.write(message)
                if not message.endswith("\n"):
                    captured.write("\n")
    return exit_code, captured.getvalue()


def _read_varint(stream: BinaryIO) -> int | None:
    """Read a base-128 varint length prefix, or None at end of stream."""
    result = 0
    shift = 0
    while True:
        chunk = stream.read(1)
        if not chunk:
            return None
        byte = chunk[0]
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result
        shift += 7


def _write_varint(stream: BinaryIO, value: int) -> None:
    while True:
        to_write = value & 0x7F
        value >>= 7
        if value:
            stream.write(bytes((to_write | 0x80,)))
        else:
            stream.write(bytes((to_write,)))
            return


def serve(stdin: BinaryIO, stdout: BinaryIO) -> int:
    """Length-delimited protobuf worker loop.

    Read a size-prefixed WorkRequest, run it, then write a size-prefixed
    WorkResponse. EOF on stdin means Bazel is done with this worker; shut down
    cleanly. This is a singleplex worker (request_id is 0 and echoed back); it
    does not advertise cancellation, so cancel requests never arrive.
    """
    while True:
        size = _read_varint(stdin)
        if size is None:
            return 0
        request = worker_protocol_pb2.WorkRequest()
        request.ParseFromString(stdin.read(size))

        exit_code, output = _run_compiler(list(request.arguments))
        response = worker_protocol_pb2.WorkResponse(
            request_id=request.request_id,
            exit_code=exit_code,
            output=output,
        )
        serialized = response.SerializeToString()
        _write_varint(stdout, len(serialized))
        stdout.write(serialized)
        stdout.flush()


def main() -> int:
    argv = sys.argv[1:]
    if "--persistent_worker" in argv:
        return serve(sys.stdin.buffer, sys.stdout.buffer)
    # One-shot fallback: behave like a normal action wrapper.
    glyphc.run(_expand_flagfiles(argv))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
