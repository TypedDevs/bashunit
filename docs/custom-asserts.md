# Custom asserts

**bashunit** enables you to extend the language by building your custom assertions. It is ideal for custom domain assertions, which don't need to be in the core library.

:::tip
Check the internal functional tests: `tests/functional/custom_asserts_test.sh` ([link](https://github.com/TypedDevs/bashunit/blob/main/tests/functional/custom_asserts_test.sh))
:::

## assertion_failed
> `bashunit::assertion_failed <expected> <actual> <failure_condition_message?>`

## assertion_passed
> `bashunit::assertion_passed`

## Example

```bash
# Your custom assert using the bashunit facade
function assert_foo() {
  local actual="$1"

  if [[ "foo" != "$actual" ]]; then
    bashunit::assertion_failed "foo" "$actual"
    return
  fi

  bashunit::assertion_passed
}

# Your test using your custom assert
function test_assert_foo_passed() {
  assert_foo "foo"
}
```
