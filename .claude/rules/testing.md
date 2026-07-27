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

Helpers are namespaced (`bashunit::*`); assertions are bare. The unprefixed helper name
is a `command not found`, not an alias.

```bash
# Spies - track calls without changing behavior
bashunit::spy function_name
assert_have_been_called function_name
assert_have_been_called_times 2 function_name          # count first, then spy
assert_have_been_called_with function_name "arg"       # spy first, then expected
assert_have_been_called_with function_name "arg" 1     # ...of call #1
assert_have_been_called_nth_with 1 function_name "arg"

# Mocks - replace behavior
bashunit::mock date echo "2024-05-01"
bashunit::mock uname <<< "Linux"    # heredoc form ignores the call's arguments
```

Note `_times` takes the count first while `_with` takes the spy first — a swapped pair
fails the assertion rather than erroring, so it reads like a real defect.

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
# Re-record: delete the snapshot file and re-run; the assertion writes it when missing
# (so a deleted snapshot never fails — read the diff before deleting)
```

## Test Isolation

- Use `$(bashunit::temp_file)` / `$(bashunit::temp_dir)` (auto-cleaned) for file
  operations — these are functions, not variables
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
