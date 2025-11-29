#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_bashunit_when_set_up_before_script_errors() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_setup_before_script_errors.sh
  local fixture=$test_file

  local header_line="Running $fixture"
  local error_line="✗ Error: Set up before script"
  local message_line="    $fixture: line 4: invalid_function_name: command not found"
  local tests_summary="Tests:      1 failed, 1 total"
  local assertions_summary="Assertions: 0 failed, 0 total"

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "$header_line" "$actual"
  assert_contains "$error_line" "$actual"
  assert_contains "$message_line" "$actual"
  assert_contains "$tests_summary" "$actual"
  assert_contains "$assertions_summary" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_set_up_before_script_with_failing_command() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_setup_before_script_with_failing_command.sh
  local fixture=$test_file

  local header_line="Running $fixture"
  local error_line="✗ Error: Set up before script"
  local message_line="    Hook 'set_up_before_script' failed with exit code 1"
  local tests_summary="Tests:      1 failed, 1 total"
  local assertions_summary="Assertions: 0 failed, 0 total"

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "$header_line" "$actual"
  assert_contains "$error_line" "$actual"
  assert_contains "$message_line" "$actual"
  assert_contains "$tests_summary" "$actual"
  assert_contains "$assertions_summary" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_set_up_before_script_fails_with_multiple_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_setup_before_script_fails_with_multiple_tests.sh
  local fixture=$test_file

  local header_line="Running $fixture"
  local error_line="✗ Error: Set up before script"
  local message_line="    Hook 'set_up_before_script' failed with exit code 1"
  # When set_up_before_script fails, all test functions should be counted as failed
  local tests_summary="Tests:      2 failed, 2 total"
  local assertions_summary="Assertions: 0 failed, 0 total"

  local actual_raw
  set +e
  actual_raw="$(./bashunit --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file")"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "$header_line" "$actual"
  assert_contains "$error_line" "$actual"
  assert_contains "$message_line" "$actual"
  assert_contains "$tests_summary" "$actual"
  assert_contains "$assertions_summary" "$actual"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}
