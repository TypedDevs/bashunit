# Custom asserts

**bashunit** enables you to extend the language by building your custom assertions. It is ideal for custom domain assertions, which don't need to be in the core library.

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

### assertion_failed
> `bashunit::assertion_failed <expected> <actual> <failure_condition_message?>`

Marks the current assertion as failed and prints a failure message.

| Parameter | Description |
|-----------|-------------|
| `expected` | The expected value |
| `actual` | The actual value received |
| `failure_condition_message` | Optional message describing the failure condition (default: "but got") |

### assertion_passed
> `bashunit::assertion_passed`

Marks the current assertion as passed. Call this when your custom assertion succeeds.

## Examples

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

Custom assertions can call other bashunit assertions internally:

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

## Best practices

1. **Always return after failure**: Call `return` after `bashunit::assertion_failed` or `bashunit::fail` to stop execution of your custom assertion.

2. **Always mark success**: Call `bashunit::assertion_passed` or `state::add_assertions_passed` when your assertion succeeds.

3. **Use descriptive names**: Name your custom assertions clearly, e.g., `assert_valid_email`, `assert_file_contains_header`.

4. **Keep assertions focused**: Each custom assertion should test one specific condition.
