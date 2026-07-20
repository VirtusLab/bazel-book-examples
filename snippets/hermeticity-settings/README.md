# Hermeticity Settings

This snippet keeps the practical hermeticity controls of {{3.2.6:HermeticitySettings}}
in one tiny workspace so the difference between inherited environment, pinned
`--action_env`, and sandbox network blocking is observable from a few commands.

## Layout

- `.bazelrc` defines a `--config=strict` named config that pins `DEMO_VALUE`
  via `--action_env=DEMO_VALUE=fixed` and turns sandbox network access off
  with `--sandbox_default_allow_network=false`. The flags are grouped into a
  named config so the workspace stays usable without them and the meta
  commands can opt in explicitly.
- `env/print_env` is a `genrule` whose `cmd` is `echo "${DEMO_VALUE:-unset}" > $@`.
  Whatever `DEMO_VALUE` the action saw at execution time is captured in
  `print_env.txt`.
- `env/print_env_test` is a `sh_test` that reads the genrule output and
  compares it to `EXPECTED_VALUE` (default `unset`). The test fails loudly
  if the action environment did not match what the build flags should have
  produced.
- `network/requires_network` is a `genrule` tagged `requires-network`. Its
  `cmd` is a deterministic `echo no-op`, so it is safe under validation on
  every OS and execution strategy. It exists as the article anchor for the
  sandbox-network discussion, not as a real network probe.

## Inherited env vs `--action_env`

Bazel 9 enables `--incompatible_strict_action_env` by default. With strict
action env, an action's command environment is a fixed minimal baseline
plus whatever `--action_env` adds. Two paths make the difference visible:

```bash
# 1. No --action_env: DEMO_VALUE is not in the action environment.
bazel test //env:print_env_test
# print_env.txt = "unset"; check_env.sh defaults EXPECTED_VALUE to "unset".

# 2. Pinned via --config=strict (which sets --action_env=DEMO_VALUE=fixed).
bazel test --config=strict --test_env=EXPECTED_VALUE=fixed //env:print_env_test
# print_env.txt = "fixed"; check_env.sh sees EXPECTED_VALUE=fixed.
```

Run the second command without `--config=strict` (or without
`--action_env=DEMO_VALUE=fixed` directly) and the genrule output flips back
to `unset`, even if `DEMO_VALUE` is exported in the invoking shell, because
strict action env stops Bazel from forwarding the client environment.

The inheriting form `--action_env=DEMO_VALUE` (no `=value`) reads the
variable from the invoking shell, which reintroduces the per-machine
divergence that strict action env is designed to prevent. Use it only for
variables that must vary per host and accept the cache impact, as
{{3.2.6:HermeticitySettings}} explains.

## Sandbox network blocking

`--sandbox_default_allow_network=false` blocks network access for sandboxed
actions. Targets that legitimately need the network opt out with `tags =
["requires-network"]`, which is why the anchor genrule carries that tag.

To see the flag actually block an action, replace the `cmd` of
`network/requires_network` with something that opens a socket, for example:

```python
genrule(
    name = "requires_network",
    outs = ["requires_network.txt"],
    cmd = "curl --max-time 1 --silent --output $@ https://127.0.0.1:1 || echo offline > $@",
    tags = ["requires-network"],
)
```

Then build it twice:

```bash
# Sandboxed action allowed to reach the network (Bazel default):
bazel build //network:requires_network

# Sandboxed action blocked from reaching the network:
bazel build --sandbox_default_allow_network=false //network:requires_network
```

Caveats that make a permanent demo here flaky:

- The block applies only to **sandboxed** execution. Actions running with
  `--spawn_strategy=local`, `--spawn_strategy=standalone`, or remote
  execution see the host's normal network policy regardless of this flag.
- macOS and Linux honor the flag through their respective sandbox
  implementations; on Windows the sandbox does not implement network
  blocking, so the flag has no effect.
- A real network probe to any non-localhost address depends on the
  developer or CI machine actually having network connectivity, which is
  exactly the kind of host coupling this snippet is trying to avoid in its
  validation commands. The README example above uses `127.0.0.1:1`, a
  guaranteed-fail address, so the action's `curl` call still terminates in
  bounded time on either side of the flag, and the `|| echo offline`
  fallback keeps the cmd's exit code stable.

The anchor target plus this README are enough for the article link; the
deterministic env demo is what makes the lesson reproducible.
