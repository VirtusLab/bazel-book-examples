# Genrule Sandbox Paths

This snippet pins the path-handling rules from {{3.4.1:Genrule}} against the
sandbox visibility constraints from {{2.3:Hermeticity}} and the
strategy/mnemonic vocabulary from {{2.5.2:StrategyVocabulary}}. One target uses
Bazel's Make variables for every path; two deliberately wrong targets show what
happens when a genrule guesses paths or skips a declaration.

The two broken targets are intentional. They exist to demonstrate the failure
modes the article calls out, not as bugs to be fixed in this workspace. The
matching `expect: error` commands in `meta.yaml` lock that contract in.

## Layout

- `config/input.txt` — small text file consumed by the correct genrule.
- `config/converter.sh` — uppercases its input file and prints the result. It
  is wrapped in a `sh_binary` named `:converter` so it can plug into a
  genrule's `tools` attribute and be referenced through `$(execpath)`.
- `config/BUILD.bazel` — the three genrules the rest of this snippet exists
  to compare.

## The correct genrule

`//config:generated_good` runs `:converter` over `input.txt` and writes the
result to `generated_good.txt` inside the rule's output directory. Every path
in `cmd` is a Make variable Bazel resolves at action time:

- `$(execpath :converter)` resolves to the sandbox path where Bazel stages
  the `:converter` tool. `:converter` is declared in `tools`, so the
  reference is legal and the binary actually lands in the sandbox.
- `$(location :input.txt)` resolves to the staged path of `input.txt`. The
  label is declared in `srcs`, so Bazel knows it is an input and stages it.
- `$(RULEDIR)` resolves to the action's output directory under
  `bazel-out/<config>/bin/config/`. Writing the output as
  `$(RULEDIR)/generated_good.txt` is equivalent to `$@` for a single-output
  genrule but spelled out so the article's Make-variable anatomy reads cleanly
  on the same line.

`bazel aquery //config:generated_good` is the quickest way to confirm the
resolved inputs and the output path Bazel actually plans to use.

## Broken: hard-coded source-tree path

`//config:bad_relative_path` writes `cat config/input.txt > $@`. There is no
`srcs` attribute, so Bazel never stages `config/input.txt` into the action's
sandbox. Under Bazel 9's default sandboxed execution on Linux and macOS, the
working directory is the sandboxed execroot, not the source tree, and the
file is not present:

```none
ERROR: ... action 'Executing genrule //config:bad_relative_path' failed:
  cat: config/input.txt: No such file or directory
```

Two notes that make this the canonical "treats the source tree as the
filesystem" bug:

- Switching to `--spawn_strategy=local` (or `--strategy=Genrule=local` from
  the example in {{2.5.2:StrategyVocabulary}}) would make the failure
  disappear because the action then runs unsandboxed in the normal execroot,
  whose source-tree view exposes `config/input.txt`. That is the host leak {{2.3:Hermeticity}} warns
  against: the sandbox is doing its job by exposing the missing declaration,
  not creating the problem.
- Even if `input.txt` were declared in `srcs`, hard-coding `config/input.txt`
  would still be wrong for any *generated* input, which is staged under
  `bazel-out/...` rather than at its package path. Make variables resolve in
  both cases; hand-rolled paths only happen to work for source files staged
  at their package path.

## Broken: tool referenced without `tools`

`//config:missing_tool_decl` references `$(execpath :converter)` in `cmd` but
omits `:converter` from `tools` (and from `srcs` / `outs`). Make-variable
resolution requires the label to be declared on the target, so the build
fails at analysis time before any action is scheduled:

```none
ERROR: ... in cmd attribute of genrule rule //config:missing_tool_decl:
  label '//config:converter' in $(location) expression is not a declared
  prerequisite of this rule
```

Bazel reports the diagnostic as `$(location)` even though the source uses
`$(execpath)`; the two Make variables share a parser and resolution rule, and
the loader's error string uses the older spelling.

That is the {{3.4.1:Genrule}} rule "tools belong in `tools`" expressed as a
loader-time guard. The action never runs, the sandbox never starts, and there
is nothing to debug at runtime — the BUILD file is rejected first.

## What the commands teach

| Command | Outcome | Lesson |
| --- | --- | --- |
| `bazel build //config:generated_good` | success | Make variables resolve to sandbox-correct paths. |
| `bazel build //config:bad_relative_path` | error | Source-tree paths break under sandboxed execution; the host is not part of the build. |
| `bazel build //config:missing_tool_decl` | error | `$(execpath LABEL)` requires `LABEL` to be declared on the target — analysis catches the bug before any action runs. |
| `bazel aquery //config:generated_good` | success | Reveals the action's resolved inputs and output path; the `aquery` reference for the article's debugging section. |
