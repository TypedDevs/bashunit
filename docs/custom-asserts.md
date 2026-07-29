---
description: "Write custom assertions in bashunit to extend the testing framework with reusable, project-specific checks for your bash scripts."
---

# Custom asserts

Custom assertions let you extend **bashunit** with your own reusable checks, ideal for domain-specific assertions that don't need to live in the core library.

:::tip
Check the internal functional tests: `tests/functional/custom_asserts_test.sh` ([link](https://github.com/TypedDevs/bashunit/blob/main/tests/functional/custom_asserts_test.sh))
:::

::: info Assertion behavior
When using the bashunit facade, assertions automatically respect the guard behavior: if a previous assertion in the same test already failed, subsequent assertions are skipped. This matches popular testing libraries default behavior.
:::

::: info Test name detection
Custom assertions automatically display the correct **test function name** in failure messages, not the custom assertion name. This makes it easy to identify which test failed, even when using deeply nested custom assertions.
:::

## API Reference

### assert_that
> `bashunit::assert_that <expected> <actual> <cmd> [args...]`

Runs `cmd` and marks the assertion passed or failed accordingly, in a single call.

| Parameter | Description |
|-----------|-------------|
| `expected` | What the assertion expects, as shown in the failure block |
| `actual` | The actual value received |
| `cmd [args...]` | The command deciding the verdict: exit `0` passes, anything else fails |

Returns `0` when the command succeeds and `1` when it fails, so it can be chained.

The command is invoked directly, without `eval`, so arguments keep their word
boundaries and nothing is re-parsed by the shell.

### assertion_failed
> `bashunit::assertion_failed <expected> <actual> <failure_condition_message?> <label?>`

Marks the current assertion as failed and prints a failure message.

| Parameter | Description |
|-----------|-------------|
| `expected` | The expected value |
| `actual` | The actual value received |
| `failure_condition_message` | Optional message describing the failure condition (default: "but got") |
| `label` | Optional name shown in the failure block (default: the test function name) |

### assertion_passed
> `bashunit::assertion_passed`

Marks the current assertion as passed. Call this when your custom assertion succeeds.

## Examples

### One-call assertion

`bashunit::assert_that` collapses the pass/fail bookkeeping into a single line,
so the two counters cannot drift apart:

```bash
function assert_positive_number() {
  bashunit::assert_that "positive number" "$1" test "$1" -gt 0
}

function test_value_is_positive() {
  assert_positive_number 1   # Passes
}

function test_value_is_not_positive() {
  assert_positive_number 0   # Fails with: "Expected 'positive number' but got '0'"
}
```

Any command works as the verdict, not only `test`:

```bash
function assert_valid_json() {
  bashunit::assert_that "valid JSON" "$1" jq -e . <<< "$1"
}

function assert_file_is_executable() {
  bashunit::assert_that "an executable file" "$1" test -x "$1"
}
```

### Naming your own failures

By default a failure block is labelled with the test function name. Pass a
fourth argument to `bashunit::assertion_failed` when the assertion should name
itself instead:

```bash
function assert_http_success() {
  local status_code="$1"

  if [ "$status_code" -lt 200 ] || [ "$status_code" -ge 300 ]; then
    bashunit::assertion_failed "a 2xx status" "$status_code" "but got " "Assert HTTP success"
    return
  fi

  bashunit::assertion_passed
}
```

### Basic custom assertion

```bash
function assert_foo() {
  local actual="$1"

  if [[ "foo" != "$actual" ]]; then
    bashunit::assertion_failed "foo" "$actual"
    return
  fi

  bashunit::assertion_passed
}

function test_value_is_foo() {
  assert_foo "foo"  # Passes
}

function test_value_is_not_foo() {
  assert_foo "bar"  # Fails with: "Failed: Value is not foo"
}
```

### Using fail() for simple messages

You can also use `bashunit::fail` for custom assertions that just need a message:

```bash
function assert_valid_json() {
  local json="$1"

  if ! echo "$json" | jq . > /dev/null 2>&1; then
    bashunit::fail "Invalid JSON: $json"
    return
  fi

  bashunit::assertion_passed
}

function test_api_returns_valid_json() {
  local response='{"status": "ok"}'
  assert_valid_json "$response"
}
```

### Composing with existing assertions

Custom assertions can call other [bashunit assertions](/assertions) internally:

```bash
function assert_http_success() {
  local status_code="$1"

  assert_greater_or_equal_than "200" "$status_code"
  assert_less_than "300" "$status_code"
}

function test_api_returns_success() {
  local status_code=200
  assert_http_success "$status_code"
}
```

### Custom assertion with custom failure message

```bash
function assert_positive_number() {
  local actual="$1"

  if [[ "$actual" -le 0 ]]; then
    bashunit::assertion_failed "positive number" "$actual" "got"
    return
  fi

  bashunit::assertion_passed
}
```

## Loading your assertions once

Sourcing a shared assertions file from `set_up` re-runs it for every test, and
only in the file that does it. Load it once for the whole run with a bootstrap
file instead:

```bash
./bashunit --boot tests/bootstrap.sh tests/
```

```bash
# .env or bashunit.env
BASHUNIT_BOOTSTRAP="tests/bootstrap.sh"
```

Your `tests/bootstrap.sh` then sources the assertions:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/custom_asserts.sh"
```

See [Configuration](/configuration) and [Command line](/command-line) for the
full bootstrap options.

## Best practices

1. **Prefer `bashunit::assert_that`**: one call marks the assertion passed or failed, so you cannot forget the `return` after a failure (which would bump both counters) or forget `bashunit::assertion_passed` (which would leave the test with zero assertions, reported as risky).

2. **Always return after failure**: when writing the long form by hand, call `return` after `bashunit::assertion_failed` or `bashunit::fail` to stop execution of your custom assertion.

3. **Always mark success**: Call `bashunit::assertion_passed` or `state::add_assertions_passed` when your assertion succeeds.

4. **Use descriptive names**: Name your custom assertions clearly, e.g., `assert_valid_email`, `assert_file_contains_header`.

5. **Keep assertions focused**: Each custom assertion should test one specific condition.

## Related

- [Assertions](/assertions) — the built-in assertion reference
- [Globals](/globals) — `bashunit::` helper functions
- [Common patterns](/common-patterns) — real-world testing patterns
