# Select Error Patterns

This snippet keeps several `select()` failure modes in one tiny workspace.

Use `//app:missing_default` and `//app:missing_default_custom` to compare the
default unmatched-configuration error with a custom `no_match_error`.

Use `//app:macro_select_error` for the macro boundary lesson. The macro does not
fail while the package is loading because that would prevent the other targets
in `//app` from being inspected. Instead, it makes the wrong loading-phase
decision after seeing the unresolved `select()` object and emits a target whose
action fails with an explanatory message. This demonstrates the "macros cannot
inspect the resolved branch" problem without making the whole package unusable.

Use `bazel query 'deps(//app:server)'` and `bazel cquery 'deps(//app:server)'
--platforms=//platforms:linux` to compare loading-phase dependency shape with
the configured graph after branch resolution.
