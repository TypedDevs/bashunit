## assertArrayContains
**Syntax**
```bash
assertArrayContains "expected" "actual elements on the array"
```

**Examples:**
```bash
function test_should_assert_that_an_array_contains_1234() {
  local distros=(Ubuntu 1234 Linux\ Mint)
  assertArrayContains "1234" "${distros[@]}"
}
```

## assertArrayNotContains
**Syntax**
```bash
assertArrayNotContains "expected" "actual elements on the array"
```

**Examples:**
```bash
function test_should_assert_that_an_array_not_contains_1234() {
  local distros=(Ubuntu 1234 Linux\ Mint)
  assertArrayNotContains "a_non_existing_element" "${distros[@]}"
}
```

## Example

Check out this [simple example](https://github.com/TypedDevs/bashunit/tree/main/example) using **bashunit**, or a more "real" example in the original repository where the idea grew up: [Chemaclass/conventional-commits](https://github.com/Chemaclass/conventional-commits/blob/main/tests/prepare-commit-msg_test.sh).
