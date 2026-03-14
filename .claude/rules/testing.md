---
paths:
  - "tests/**/*_test.sh"
---

# Testing Guidelines

## Organization

| Directory | Purpose | Pattern |
|-----------|---------|---------|
| `tests/unit/` | Isolated function tests | Mocks/spies for deps |
| `tests/functional/` | Multi-component integration | Real interactions |
| `tests/acceptance/` | CLI/end-to-end workflows | Full user scenarios |

**Naming:** Files end with `_test.sh`. Functions: `test_should_<behavior>_when_<condition>`

## Assertions

```bash
assert_equals "expected" "$actual"
assert_not_equals "not_this" "$actual"
assert_contains "substring" "$haystack"
assert_not_contains "substring" "$haystack"
assert_matches "regex" "$string"
assert_not_matches "regex" "$string"
assert_empty "$var"
assert_not_empty "$var"
assert_successful_code "$?"
assert_general_error "$?"
assert_file_exists "$path"
assert_file_not_exists "$path"
assert_directory_exists "$path"
assert_array_contains "value" "${array[@]}"
assert_array_not_contains "value" "${array[@]}"
assert_fails "assert_equals 'a' 'b'"
```

## Test Doubles

```bash
# Spies - track calls without changing behavior
spy function_name
assert_have_been_called function_name
assert_have_been_called_times 2 function_name
assert_have_been_called_with "arg" function_name

# Mocks - replace behavior
mock curl echo "mocked response"
```

## Data Providers

```bash
function data_provider_inputs() {
  echo "5 3 8"
  echo "0 0 0"
}

# @data_provider data_provider_inputs
function test_should_add() {
  assert_equals "$3" "$(add "$1" "$2")"
}
```

## Lifecycle Hooks

- `set_up_before_script()` — once before all tests in file
- `set_up()` — before each test
- `tear_down()` — after each test
- `tear_down_after_script()` — once after all tests in file

## Snapshot Testing

```bash
assert_match_snapshot "$output"
# Update: ./bashunit --update-snapshots tests/acceptance/
```

## Test Isolation

- Use `$temp_file` / `$temp_dir` (auto-cleaned) for file operations
- No shared global state between tests
- No network calls — mock external commands
- No time dependencies — mock `date` if needed
- Tests must be safe for `./bashunit --parallel tests/`

## Reference Tests

- **Assertions:** `tests/unit/assert_test.sh`
- **Doubles:** `tests/functional/doubles_test.sh`
- **Providers:** `tests/functional/provider_test.sh`
- **Hooks:** `tests/unit/setup_teardown_test.sh`
- **CLI/snapshots:** `tests/acceptance/bashunit_test.sh`
