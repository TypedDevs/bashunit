#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_no_fork_shows_warning_message() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-fork "$test_file" 2>&1)

  assert_contains "Warning: --no-fork mode enabled" "$output"
  assert_contains "without subshell isolation" "$output"
}

function test_no_fork_tests_pass_correctly() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-fork "$test_file" 2>&1)

  assert_contains "4 passed" "$output"
  assert_contains "All tests passed" "$output"
}

function test_no_fork_assertions_are_counted() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-fork "$test_file" 2>&1)

  # Should count all assertions from the fixture tests (6 assertions total)
  assert_contains "Assertions:" "$output"
  assert_contains "6 passed" "$output"
}

function test_no_fork_failing_tests_are_detected() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-fork "$test_file" 2>&1) || true

  assert_contains "1 failed" "$output"
  assert_contains "There was 1 failure" "$output"
}

function test_no_fork_via_env_variable() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(BASHUNIT_NO_FORK=true ./bashunit --no-parallel --skip-env-file "$test_file" 2>&1)

  assert_contains "Warning: --no-fork mode enabled" "$output"
  assert_contains "4 passed" "$output"
}

function test_no_fork_with_multiple_test_files() {
  local test_file1=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local test_file2=./tests/acceptance/fixtures/test_bashunit_when_a_second_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-fork "$test_file1" "$test_file2" 2>&1)

  assert_contains "All tests passed" "$output"
  # Should have tests from both files
  assert_contains "Tests:" "$output"
}
