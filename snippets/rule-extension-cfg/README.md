# Rule Extension With a cfg Transition

This snippet pins how a rule extension adds an incoming configuration
transition to a rule that another module owns, on Bazel 9.1.0. It backs
{{4.12.2:CtxSuper}} and touches {{4.7.2:StarlarkTransitions}} and
{{4.7.4:TransitionGotchas}}.

`third_party/upstream_rules` is a separate module, wired in with
`local_path_override`, that stands in for a ruleset you consume but do not
edit. Its `mode_report` rule writes `<target>: <compilation mode>` for the
target and each of its deps, so every report file shows which configuration
each target was really built in.

## Layout

| Path | Purpose |
| --- | --- |
| `third_party/upstream_rules/report.bzl` | The "upstream" rules: `mode_report`, `dbg_report` (owns a `cfg` that sets `dbg`), `sealed_report` (`extendable = False`), `titled_report` (a public string attribute and a private label attribute), and the macro `mode_report_macro` |
| `rules/opt.bzl` | `opt_transition` plus two pass-through extensions: `opt_mode_report` and `opt_dbg_report` |
| `rules/company.bzl` | A drop-in extension that keeps the name `mode_report` and adds a `sorted` output group |
| `app/BUILD.bazel` | `plain` (upstream), `optimized` (extension), `pinned` (extension of `dbg_report`), all depending on `lib` |
| `dropin/BUILD.bazel` | Targets that call the drop-in `mode_report`, plus a `filegroup` that picks the `sorted` output group |
| `errors/extend_macro/` | Uses the macro as `parent` (fails) |
| `errors/sealed_parent/` | Extends `sealed_report` (fails) |
| `errors/native_parent/` | Uses `native.genrule` as `parent` (fails) |
| `errors/super_not_called/`, `errors/super_twice/` | Call `ctx.super()` zero times or twice (fail) |
| `errors/provider_index/` | Indexes the `ctx.super()` list with `DefaultInfo` (fails) |
| `errors/duplicate_output_group/` | Extends the drop-in rule and appends a second `OutputGroupInfo` (fails) |
| `errors/override_*` | Override a string attribute, change an attribute's type, override a private attribute, or change required providers (all fail) |
| `tools/assert_rule_extension.sh` | Runs every scenario and checks the report files, query output, and errors |

## Behavior on Bazel 9.1.0

| Command | Result |
| --- | --- |
| `bazel build //app:plain` | `plain: fastbuild`, `lib: fastbuild` |
| `bazel build //app:optimized` | `optimized: opt`, `lib: opt`. The transition reaches the deps |
| `bazel build //app:pinned` | `pinned: dbg`, `lib: dbg`. The parent's own `cfg` runs after the child's and wins |
| `bazel cquery 'deps(//app:plain) + deps(//app:optimized)'` | `//app:lib` appears twice, once per configuration |
| `bazel query 'kind(opt_mode_report, //app:all)' --output=label_kind` | `opt_mode_report rule //app:optimized` |
| `bazel query 'kind("^mode_report rule$", //app:all + //dropin:all)'` | Lists the upstream targets and the drop-in targets together |
| `bazel build //dropin:sorted` | The `sorted` output group holds the parent's report, sorted by the child's extra action |
| `bazel build //errors/extend_macro:report` | `Error in rule: Parent needs to be a Starlark rule, was function` |
| `bazel build //errors/sealed_parent:report` | `Error in rule: The rule 'sealed_report' is not extendable. ...` |
| `bazel build //errors/native_parent:report` | `Error in rule: Parent needs to be a Starlark rule, was rule` |
| `bazel build //errors/super_not_called:report` | `'super' was not called.` |
| `bazel build //errors/super_twice:report` | `'super' called the second time.` |
| `bazel build //errors/provider_index:report` | `got Provider for sequence index, want int` |
| `bazel build //errors/duplicate_output_group:report` | `Multiple conflicting returned providers with key OutputGroupInfo` |
| `bazel build //errors/override_string_attr:report` | ``attribute `title`: Only label types maybe be overridden.`` |
| `bazel build //errors/override_type_mismatch:report` | ``attribute `deps`: Types of parent and child's attributes mismatch.`` |
| `bazel build //errors/override_private_attr:report` | ``attribute `_template`: private attributes cannot be overridden.`` |
| `bazel build //errors/override_providers:report` | ``attribute `deps`: can't override required providers`` |

The transitioned outputs live in a different `bazel-out/<config>/bin`
directory than `bazel-bin`, so read them through
`bazel cquery <label> --output=files` rather than `bazel-bin/`.

## Run it

```bash
cd knowledge/examples/snippets/rule-extension-cfg
bazel build //app:optimized
cat "$(bazel cquery //app:optimized --output=files)"
bash tools/assert_rule_extension.sh
```
