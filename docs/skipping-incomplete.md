---
description: "Mark bash tests as skipped or incomplete in bashunit to handle cases beyond simple pass or fail and keep your test suite expressive and clear."
---

# Skipping and incomplete tests

There may be various scenarios where the "passed" and "failed" outcomes for a test are not sufficient.
To address these situations, the following functions are available for your use.

## bashunit::skip
> `bashunit::skip "[reason]"`

Not all tests can be run in every environment; when such situations arise, you can mark a test as skipped.

It reports that the test has been skipped, including the `[reason]` if one was specified.

Skipping tests will not cause **bashunit** to exit with an error code;
however, it will indicate that some tests were skipped in the final output.

::: code-group
```bash [Example]
function test_skipped() {
  if [[ $OS != "GEOS" ]]; then
    bashunit::skip && return
  fi

  assert_empty "not reached"
}

function test_skipped_with_reason() {
  if [[ $OS != "GEOS" ]]; then
    bashunit::skip "Not running under Commodore" && return
  fi

  assert_empty "not reached"
}
```
```[Output]
↷ Skipped: Skipped
↷ Skipped: Skipped with reason
    Not running under Commodore

Tests:      2 skipped, 2 total
Assertions: 2 skipped, 2 total
Some tests skipped
```
:::

## Conditional skips

`bashunit::skip` marks the test skipped but does **not** stop it, which is why
every example above ends in `&& return`. The four helpers below do both: they
mark the test skipped and end it right there.

> `bashunit::skip_if <condition> "[reason]"`
> `bashunit::skip_unless <condition> "[reason]"`
> `bashunit::skip_unless_command <command> [<command>…]`
> `bashunit::skip_on <windows|macos|linux> "[reason]"`

The condition of `skip_if`/`skip_unless` is evaluated as a shell command, so it
may carry arguments. `skip_unless_command` takes any number of commands and
reports `requires <command>` for the first one missing. `skip_on` accepts
`windows`, `macos` or `linux`; any other name is a usage error rather than a
test that silently never skips.

::: code-group
```bash [Example]
function test_file_permissions() {
  bashunit::skip_on windows "Git Bash fakes POSIX permissions"

  assert_file_permissions 644 "$file"
}

function test_decimal_math() {
  bashunit::skip_unless_command bc

  assert_equals "4.0" "$(calculate "1.5 + 2.5")"
}

function test_only_locally() {
  bashunit::skip_if "[ -n \"${CI:-}\" ]" "too slow for CI"

  assert_successful_code "$(long_running_job)"
}
```
```[Output]
↷ Skipped: File permissions
    Git Bash fakes POSIX permissions
↷ Skipped: Decimal math
    requires bc

Tests:      2 skipped, 1 passed, 3 total
```
:::

::: tip
Called from inside a test's own `$(...)` subshell, these helpers end that
subshell only — the same as any `exit`. Call them from the test body.
:::

## bashunit::todo
> `bashunit::todo "[pending]"`

You may come up with a test that you'd like to implement later.
Instead of leaving the test implementation empty —which would mark the test as complete— you can flag it as incomplete.

Reports that the test is incomplete as it is under development, including any `[pending]` to do details if specified.

Incomplete tests will not cause **bashunit** to exit with an error code;
however, it will indicate that some tests were incomplete in the final output.

::: code-group
```bash [Example]
function test_incomplete() {
  bashunit::todo
}

function test_incomplete_with_pending_details() {
  bashunit::todo "Detailed description of what needs to be done"
}
```
```[Output]
✒ Incomplete: Incomplete
✒ Incomplete: Incomplete with pending details
    Detailed description of what needs to be done

Tests:      2 incomplete, 2 total
Assertions: 2 incomplete, 2 total
Some tests incomplete
```
:::

## Related

- [Assertions](/assertions) — the built-in assertion reference
- [Test files](/test-files) — test discovery and lifecycle hooks
- [Command line](/command-line) — CLI flags and options
