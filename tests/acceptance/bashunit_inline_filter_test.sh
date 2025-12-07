#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_double_colon_syntax_runs_specific_test() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "tests/acceptance/fixtures/tests_path/a_test.sh::test_assert_empty")

  assert_contains "1 passed" "$output"
  assert_contains "Assert empty" "$output"
}

function test_double_colon_syntax_with_partial_match() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "tests/acceptance/fixtures/tests_path/a_test.sh::test_assert")

  assert_contains "2 passed" "$output"
}

function test_line_number_syntax_runs_specific_test() {
  local output
  # Line 4 should be inside test_assert_greater_and_less_than (starts at line 3)
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "tests/acceptance/fixtures/tests_path/a_test.sh:4")

  assert_contains "passed" "$output"
  assert_contains "Assert greater and less than" "$output"
}

function test_line_number_at_second_function() {
  local output
  # Line 9 should be inside test_assert_empty (starts at line 8)
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "tests/acceptance/fixtures/tests_path/a_test.sh:9")

  assert_contains "1 passed" "$output"
  assert_contains "Assert empty" "$output"
}

function test_line_number_before_any_test_shows_error() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "tests/acceptance/fixtures/tests_path/a_test.sh:1" 2>&1) || true

  assert_contains "No test function found" "$output"
}

function test_double_colon_syntax_no_match_runs_nothing() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "tests/acceptance/fixtures/tests_path/a_test.sh::nonexistent_test" 2>&1) || true

  assert_contains "0 total" "$output"
}

function test_regular_filter_option_still_works() {
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --filter "test_assert_empty" "tests/acceptance/fixtures/tests_path/a_test.sh")

  assert_contains "1 passed" "$output"
}
