---
scope: tests
---

# Testing

Read sibling tests before writing a new fixture. Repository paths are relative to the repository root.

| Layer | Directory | Scope |
|-------|-----------|-------|
| Unit | `tests/unit/` | Isolated helpers, mocked dependencies |
| Functional | `tests/functional/` | Real component interactions |
| Acceptance | `tests/acceptance/` | CLI and end-to-end behavior |

Files end in `_test.sh`; name tests for the behavior and trigger. Run the quality gate from `AGNOSTIC_AI.md` once when the change set is complete. Test success, failure and cleanup paths that the change affects; verify parallel behavior when state or workers change.

## Assertions and doubles

Assertions are bare functions (`assert_equals`, `assert_same`, `assert_contains`, `assert_not_contains`, `assert_successful_code`, `assert_general_error`, `assert_file_exists`, `assert_file_not_exists`). Helpers and doubles use `bashunit::*`. Inspect the matching assertion before guessing its signature. There is no `assert_fails`.

```bash
bashunit::spy function_name
assert_have_been_called function_name
assert_have_been_called_times 2 function_name
assert_have_been_called_with function_name "arg"
assert_have_been_called_with function_name "arg" 1
assert_have_been_called_nth_with 1 function_name "arg"
assert_have_been_called_with_args function_name "a b"
bashunit::mock date echo "2024-05-01"
bashunit::mock uname <<< "Linux"
```

`_times` takes the count first; `_with` takes the spy first and an optional call index last. `_with_args` compares argument boundaries. To test a failing assertion, compare its captured output with the corresponding renderer, as sibling tests do.

Providers emit one argument row per line and are selected with `# @data_provider <function>`. Keep parser quoting, empty arguments and row isolation intact. Hooks are `set_up_before_script`, `set_up`, `tear_down`, and `tear_down_after_script`; the script hooks run once per file, the others per test.

Use `assert_match_snapshot` or `assert_match_named_snapshot`; update snapshots deliberately with `./bashunit --snapshot-update --filter <function-name> tests/`.

## Isolation

- Use `$(bashunit::temp_file)` or `$(bashunit::temp_dir)` for framework-cleaned fixtures. No shared fixed temporary paths or global state between tests.
- Mock network calls and nondeterministic external dependencies. Tests must work under `./bashunit --parallel tests/`.
- Embedded test-function definitions are scanned textually by the duplicate check, even inside strings. Give every embedded definition a unique name across its containing file; quote-state heuristics cannot safely hide them.
- Strict CI (`make test/strict`) uses `set -euo pipefail`: initialize arrays, guard optional elements, use `if` for conditional side effects, and isolate `extdebug` in a subshell. Simple output contains markers, so test rendering helpers rather than assuming full `print_line` output.

Start with `tests/unit/assert/`, `tests/functional/doubles_test.sh`, `tests/functional/provider_test.sh`, `tests/unit/runner/hooks_test.sh`, and `tests/acceptance/bashunit_test.sh`. Use `rg` to locate the matching function tests before adding a pattern.
