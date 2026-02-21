#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_bashunit_when_tear_down_after_script_errors() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_after_script_errors.sh
  local fixture=$test_file

  local header_line="Running $fixture"
  local error_line="✗ Error: Tear down after script"
  local message_line="    $fixture: line 4: missing_cleanup_command: command not found"
  local tests_summary="Tests:      1 passed, 1 failed, 2 total"
  local assertions_summary="Assertions: 0 passed, 0 failed, 0 total"

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

function test_bashunit_when_tear_down_after_script_with_failing_command() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_teardown_after_script_with_failing_command.sh
  local fixture=$test_file

  local header_line="Running $fixture"
  local error_line="✗ Error: Tear down after script"
  local message_line="    Hook 'tear_down_after_script' failed with exit code 1"
  local tests_summary="Tests:      1 passed, 1 failed, 2 total"
  local assertions_summary="Assertions: 1 passed, 0 failed, 1 total"

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

function test_bashunit_when_tear_down_after_script_with_intermediate_failing_command() {
  local test_file
  test_file=./tests/acceptance/fixtures/\
test_bashunit_when_teardown_after_script_with_intermediate_failing_command.sh
  local fixture=$test_file

  local header_line="Running $fixture"
  local error_line="✗ Error: Tear down after script"
  local message_line="    Hook 'tear_down_after_script' failed with exit code 1"
  local tests_summary="Tests:      1 passed, 1 failed, 2 total"
  local assertions_summary="Assertions: 1 passed, 0 failed, 1 total"

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
