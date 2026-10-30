---
description: "How bashunit discovers test files and functions, sets test titles, and runs setup and cleanup hooks."
---

# Test files

bashunit discovers tests by file and function names. Lifecycle hooks handle setup and cleanup.

## Test file names

Pass a directory to run all files ending in `test.sh` or `test.bash` within it, including subdirectories.

When using wildcards, include the test-file suffix in the pattern (for example, `**/*test.sh` or `**/*test.bash`) to limit the initial search. This also separates tests from production code, [mocks](/test-doubles), stubs, and fixtures in shared directories.

## Test function names

Within each test file, bashunit runs functions whose names start with the literal lowercase prefix `test_`, including the underscore. For example:

::: code-group
```bash [Example]
function test_should_validate_an_ok_exit_code() { ... }
function test_getFunctionsToRun_with_filter_should_return_matching_functions { ... }
test_render_all_tests_passed_when_not_failed_tests() { ... }
```
:::

::: tip
All three Bash function forms are supported: `function name()`, `name()`, and `function name` without parentheses. Discovery uses the function name.
:::

::: warning
`test_` is matched literally, so `testRenderAllTests` (no underscore) and `TEST_upper`
(uppercase) are **auxiliary functions**, not tests. bashunit does not warn about them: if the
file also holds a real test, the run is green and simply contains fewer tests than you wrote.
Check with [`--list`](/command-line#list) when a test you expected never appears in the output.

This is also what lets a helper named `testdata_path` stay a helper.
:::

## Custom test titles

By default, **bashunit** derives the name shown in reports from the test function name.
If you need a more descriptive title, you can override it inside the test using `bashunit::set_test_title`:

::: code-group
```bash [Example]
function test_handles_invalid_input() {
  bashunit::set_test_title "🔥 handles custom test names 🚀"
  # test logic...
}
```
:::

The provided title is used only for display purposes. The original function name is still
used internally, and custom titles are reset automatically after each test.

## Per-test annotations

`--test-timeout` and `--retry` are run-wide, but the need is usually per test:
one integration test needs 30 seconds while the other 400 stay strict. Write
the annotation in the comment block directly above the function, the same place
`# @tag` goes:

::: code-group
```bash [Example]
# @tag integration
# @timeout 30
# @retry 3
function test_slow_integration() {
  assert_successful_code "$(sync_with_the_api)"
}

# @skip needs a live database
function test_reads_from_the_database() {
  # never executed, not even set_up
  assert_not_empty "$(query "select 1")"
}
```
```[Output]
↷ Skipped: Reads from the database
    needs a live database
```
:::

| Annotation | Effect |
|---------------------|-------------------------------------------------------------|
| `@timeout <seconds>` | Overrides `--test-timeout` for this test, in both directions. `0` disables the timeout for this test even when the run sets one. |
| `@retry <n>`         | Overrides `--retry` for this test. |
| `@skip [reason]`     | Reports the test as skipped with the reason; the body and the hooks never run. |

The association follows the `# @tag` rule: other comment lines keep the block
open, a **blank line breaks it**, and both `function test_x` and `test_x()`
definition styles are recognised. A value that is not a non-negative integer
(`# @timeout abc`, `# @retry -1`) aborts the run with an error rather than
silently falling back to the default — the run would otherwise not be the one
the annotation asked for.

## `set_up` function

If defined, `set_up` runs before each test in the file. Use it to set variables or create files and directories the test needs.

::: code-group
```bash [Example]
function set_up() {
  touch temp_file.txt
}
```
:::

## `tear_down` function

If defined, `tear_down` runs immediately after each test in the file. Use it to clean up resources or changes made by `set_up` or the test.

::: code-group
```bash [Example]
function tear_down() {
  rm temp_file.txt
}
```
:::

## `set_up_before_script` function

If defined, `set_up_before_script` runs once before the file's tests. Use it to load shared resources.

During test execution, bashunit displays the hook execution with its duration, right-aligned to match test output:

```
Running tests/example_test.sh
● set_up_before_script                                               2.03s
✓ Passed: test_example                                                 12ms
```

A failing command or non-zero function status makes `set_up_before_script` fail. bashunit reports the hook error, marks **every test in the file as failed** (they are included in the totals), and continues with the next test file. Watch out for a trailing `cmd && var=value` guard: when `cmd` fails, the guard is the hook's return value. The rest of the suite always runs, and the failure is attributed to the hook rather than surfacing as mysterious individual test errors. `tear_down_after_script` still runs, so it can release resources acquired before the setup failure. Because setup may be only partially complete, guard optional state in teardown, for example `[ -n "${RESOURCE:-}" ] && rm -f "$RESOURCE"`.

If you want a missing optional dependency to skip tests instead of failing them, end the hook with an explicit success, for example `command -v jq >/dev/null 2>&1 && HAS_JQ=true; return 0`, then call `bashunit::skip` inside the tests.

::: code-group
```bash [Example]
function set_up_before_script() {
  open_database_connection
}
```
:::

## `tear_down_after_script` function

If defined, `tear_down_after_script` runs once after the file finishes, including when `set_up_before_script` fails and prevents the tests from running. Use it to delete temporary files or release shared resources.

An interrupted run (Ctrl-C, SIGTERM, or SIGHUP) still runs `tear_down` and `tear_down_after_script` and exits with status 1.

On interruption, per-test teardown gets a two-second grace period before any remaining test processes are stopped.

Like `set_up_before_script`, the execution is displayed with its duration:

```
✓ Passed: test_example                                                 12ms
● tear_down_after_script                                             1.05s

Tests:      1 passed, 1 total
```

Failures inside `tear_down_after_script` are also surfaced as dedicated errors after the final test output so cleanup problems (for example, missing tools or permissions) are visible in the run summary.

::: code-group
```bash [Example]
function tear_down_after_script() {
  close_database_connection
}
```
:::

## Syntax errors in test files

If a test file contains a Bash syntax error, **bashunit** records a failing
test for that file instead of silently skipping the remaining tests. The exact
error message from Bash (including file path and line number) is shown in the
summary, and the suite exits with a non-zero status.

```
Running tests/example_test.sh
✗ Error: Source
    tests/example_test.sh: line 10: syntax error near unexpected token `fi'
    tests/example_test.sh: line 10: `  fi'

Tests:      1 failed, 1 total
Some tests failed
```

## Related

- [Command line](/command-line) — discover and run test files from the terminal
- [Configuration](/configuration) — set the default test path and bootstrap file
- [Assertions](/assertions) — assertions to use inside your test functions
- [Common patterns](/common-patterns) — real-world testing patterns
