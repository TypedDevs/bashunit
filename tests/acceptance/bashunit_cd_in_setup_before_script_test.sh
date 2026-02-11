#!/usr/bin/env bash
set -euo pipefail

# Regression test for https://github.com/TypedDevs/bashunit/issues/532
# Subsequent tests should run when an earlier test's set_up_before_script changes directory

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_subsequent_tests_run_when_set_up_before_script_changes_directory() {
  local first_file=./tests/acceptance/fixtures/test_cd_in_setup_before_script_first.sh
  local second_file=./tests/acceptance/fixtures/test_cd_in_setup_before_script_second.sh

  local actual_raw
  actual_raw="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$first_file" "$second_file")"

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  # Both test files should run
  assert_contains "Running" "$actual"
  assert_contains "test_cd_in_setup_before_script_first.sh" "$actual"
  assert_contains "test_cd_in_setup_before_script_second.sh" "$actual"

  # Both tests should pass
  assert_contains "2 passed, 2 total" "$actual"
  assert_successful_code "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$first_file" "$second_file")"
}
