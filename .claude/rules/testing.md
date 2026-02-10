---
paths:
  - "tests/**/*_test.sh"
---

# Testing Guidelines

## Test Organization

### Directory Structure

```
tests/
├── unit/           # Unit tests for src/ functions
├── functional/     # Integration tests with real interactions
└── acceptance/     # End-to-end CLI/behavior tests
```

**Placement rules:**
- `unit/` - Tests single functions in isolation with mocks/spies
- `functional/` - Tests multiple components together
- `acceptance/` - Tests complete user workflows via CLI

### File Naming

```bash
# ✅ Test files must end with _test.sh
tests/unit/assert_test.sh
tests/functional/doubles_test.sh
tests/acceptance/bashunit_test.sh

# ✅ Test functions must start with test_
function test_should_return_expected_value() { ... }
function test_should_fail_when_invalid_input() { ... }
```

## Test Structure

### Arrange-Act-Assert Pattern

```bash
function test_should_calculate_sum() {
  # Arrange - Set up test data
  local input_a=5
  local input_b=3
  local expected=8

  # Act - Execute the function
  local actual
  actual=$(add "$input_a" "$input_b")

  # Assert - Verify the result
  assert_equals "$expected" "$actual"
}
```

### Descriptive Test Names

```bash
# ✅ Good - describes behavior and context
function test_should_return_error_when_file_not_found() { ... }
function test_should_pass_when_all_assertions_succeed() { ... }
function test_should_handle_empty_input_gracefully() { ... }

# ❌ Bad - vague or unclear
function test_function() { ... }
function test_error() { ... }
function test_case_1() { ... }
```

## Assertions

**Study official patterns:** `tests/unit/assert_test.sh`

### Core Assertions

```bash
# Equality
assert_equals "expected" "$actual"
assert_not_equals "not_this" "$actual"

# Strings
assert_contains "substring" "$haystack"
assert_not_contains "substring" "$haystack"
assert_matches "regex_pattern" "$string"
assert_not_matches "regex_pattern" "$string"

# Empty/not empty
assert_empty "$variable"
assert_not_empty "$variable"

# Exit codes
assert_successful_code "$?"
assert_general_error "$?"

# Files
assert_file_exists "$file_path"
assert_file_not_exists "$file_path"
assert_directory_exists "$dir_path"

# Arrays
assert_array_contains "value" "${array[@]}"
assert_array_not_contains "value" "${array[@]}"
```

### Testing Failures

Test that assertions fail when they should:

```bash
function test_should_fail_when_values_differ() {
  # Use assert_fails to verify assertion failure
  assert_fails \
    "assert_equals 'expected' 'different'"
}

function test_should_report_correct_error_message() {
  local output
  output=$(assert_equals "expected" "actual" 2>&1) || true

  assert_contains "expected" "$output"
  assert_contains "actual" "$output"
}
```

## Test Doubles

**Study official patterns:** `tests/functional/doubles_test.sh`

### Spies

Track function calls without changing behavior:

```bash
function test_should_call_helper_function() {
  # Create spy
  spy function_to_spy

  # Execute code that calls the spied function
  main_function

  # Verify it was called
  assert_have_been_called function_to_spy
  assert_have_been_called_times 2 function_to_spy
  assert_have_been_called_with "expected_arg" function_to_spy
}
```

### Mocks

Replace function behavior entirely:

```bash
function test_should_handle_external_command() {
  # Mock external command
  mock curl echo "mocked response"

  # Execute code that uses curl
  local result
  result=$(fetch_data "https://example.com")

  # Verify mock was used
  assert_equals "mocked response" "$result"
  assert_have_been_called curl
}
```

### Mock Files

Mock script execution:

```bash
function test_should_execute_external_script() {
  # Create mock script
  local mock_script="$temp_dir/script.sh"
  echo '#!/usr/bin/env bash' > "$mock_script"
  echo 'echo "mocked output"' >> "$mock_script"
  chmod +x "$mock_script"

  # Test with mocked script
  local output
  output=$("$mock_script")

  assert_equals "mocked output" "$output"
}
```

## Data Providers

**Study official patterns:** `tests/functional/provider_test.sh`

Test multiple inputs efficiently:

```bash
function data_provider_valid_inputs() {
  echo "5 3 8"        # input_a input_b expected
  echo "0 0 0"
  echo "-1 1 0"
  echo "100 200 300"
}

# @data_provider data_provider_valid_inputs
function test_should_add_numbers() {
  local input_a="$1"
  local input_b="$2"
  local expected="$3"

  local actual
  actual=$(add "$input_a" "$input_b")

  assert_equals "$expected" "$actual"
}
```

## Lifecycle Hooks

**Study official patterns:** `tests/unit/setup_teardown_test.sh`

### Available Hooks

```bash
# Runs once before any tests in the file
function set_up_before_script() {
  export TEST_CONFIG="global_value"
}

# Runs before each test function
function set_up() {
  temp_file=$(mktemp)
  echo "initial" > "$temp_file"
}

# Runs after each test function
function tear_down() {
  rm -f "$temp_file"
}

# Runs once after all tests in the file
function tear_down_after_script() {
  unset TEST_CONFIG
}
```

### Hook Usage

```bash
# ✅ Use for common setup
function set_up() {
  test_dir="$temp_dir/test_run"
  mkdir -p "$test_dir"
}

# ✅ Use for cleanup
function tear_down() {
  rm -rf "$test_dir"
}

# ⚠️ Avoid heavy setup in every test - use set_up_before_script
function set_up_before_script() {
  # One-time expensive operation
  compile_test_fixtures
}
```

## Snapshot Testing

**Study official patterns:** `tests/acceptance/bashunit_test.sh`

```bash
function test_should_generate_expected_output() {
  local output
  output=$(./bashunit --simple tests/example/)

  # Creates snapshot on first run, compares on subsequent runs
  assert_match_snapshot "$output"
}
```

Update snapshots when behavior intentionally changes:
```bash
./bashunit --update-snapshots tests/acceptance/
```

## Test Isolation

### Use Global Test Variables

```bash
# ✅ Available in all tests
function test_should_use_temp_file() {
  echo "data" > "$temp_file"  # Cleaned up automatically
  assert_file_exists "$temp_file"
}

function test_should_use_temp_dir() {
  local file="$temp_dir/data.txt"
  echo "content" > "$file"
  assert_file_exists "$file"
}
```

### Clean State Between Tests

```bash
# ✅ Reset in set_up
function set_up() {
  unset TEST_VAR
  declare -g TEST_VAR=""
}

# ❌ Don't rely on test order
function test_first() {
  TEST_VAR="value"  # Bad - affects other tests
}

function test_second() {
  # This might fail depending on execution order
  assert_empty "$TEST_VAR"
}
```

## Testing Best Practices

### Test Behavior, Not Implementation

```bash
# ✅ Test the behavior
function test_should_return_user_count() {
  local count
  count=$(get_user_count)
  assert_equals "5" "$count"
}

# ❌ Test implementation details
function test_should_query_database() {
  spy database_query
  get_user_count
  assert_have_been_called database_query
}
```

### Test Edge Cases

```bash
function test_should_handle_empty_input() { ... }
function test_should_handle_null_input() { ... }
function test_should_handle_large_input() { ... }
function test_should_handle_special_characters() { ... }
function test_should_handle_boundary_values() { ... }
```

### Test Both Success and Failure

```bash
function test_should_succeed_with_valid_input() { ... }
function test_should_fail_with_invalid_input() { ... }
function test_should_fail_when_file_missing() { ... }
function test_should_handle_permission_errors() { ... }
```

### One Assert Per Test (Guideline)

```bash
# ✅ Focused test
function test_should_return_correct_value() {
  assert_equals "expected" "$(get_value)"
}

# ⚠️ Multiple asserts can hide which failed
function test_should_validate_everything() {
  assert_equals "a" "$val_a"
  assert_equals "b" "$val_b"
  assert_equals "c" "$val_c"  # If this fails, might not see previous
}
```

## Avoiding Flaky Tests

### No Network Calls

```bash
# ❌ Flaky - depends on network
function test_should_fetch_from_api() {
  local result
  result=$(curl https://api.example.com)
  assert_equals "data" "$result"
}

# ✅ Mock external calls
function test_should_fetch_from_api() {
  mock curl echo "mocked data"
  local result
  result=$(fetch_from_api)
  assert_equals "mocked data" "$result"
}
```

### No Time Dependencies

```bash
# ❌ Flaky - depends on system time
function test_should_return_current_timestamp() {
  local result
  result=$(get_timestamp)
  assert_equals "$(date +%s)" "$result"
}

# ✅ Mock time
function test_should_return_current_timestamp() {
  mock date echo "1234567890"
  local result
  result=$(get_timestamp)
  assert_equals "1234567890" "$result"
}
```

### No Race Conditions

```bash
# ❌ Flaky - timing dependent
function test_should_process_async() {
  process_in_background &
  sleep 0.1  # Hope it's done...
  assert_file_exists "$output"
}

# ✅ Wait for completion
function test_should_process_async() {
  process_in_background &
  local pid=$!
  wait "$pid"
  assert_file_exists "$output"
}
```

## Performance

### Keep Tests Fast

- Mock slow operations (network, disk, external commands)
- Use `set_up_before_script` for expensive one-time setup
- Prefer unit tests over acceptance tests when possible

### Parallel Execution

Tests should be safe for parallel execution:

```bash
./bashunit --parallel tests/
```

Requirements:
- No shared global state (use `$temp_dir` for isolation)
- No hardcoded file paths (use temp files)
- Clean up resources in `tear_down`

## Validation Checklist

Before committing tests:
- [ ] All tests have descriptive names
- [ ] Tests follow Arrange-Act-Assert
- [ ] Using only verified assertions from `tests/unit/assert_test.sh`
- [ ] Proper use of mocks/spies from `tests/functional/doubles_test.sh`
- [ ] Tests isolated (no shared state)
- [ ] Tests are not flaky (no network, time, or race conditions)
- [ ] `./bashunit tests/` passes
- [ ] Tests pass in parallel: `./bashunit --parallel tests/`

## Reference Tests

Study these for patterns:
- **Assertions:** `tests/unit/assert_test.sh`
- **Test doubles:** `tests/functional/doubles_test.sh`
- **Data providers:** `tests/functional/provider_test.sh`
- **Lifecycle hooks:** `tests/unit/setup_teardown_test.sh`
- **CLI/snapshots:** `tests/acceptance/bashunit_test.sh`
