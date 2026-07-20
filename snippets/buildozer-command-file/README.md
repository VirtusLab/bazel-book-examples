# Buildozer Command File

This snippet keeps the Buildozer workflow reviewable without requiring the
`buildozer` binary during validation. The BUILD file contains the target shapes
that Buildozer commands usually address, and the helper script emits a command
file a maintainer can inspect before applying it.

Try:

```bash
bazel run //tools:write_buildozer_cmds
cat buildozer-cmds.txt
```

The generated file demonstrates a single-target edit, the `//pkg:*`
all-rules-in-package form, a kind-filtered target form, and the `__pkg__`
package target form.
