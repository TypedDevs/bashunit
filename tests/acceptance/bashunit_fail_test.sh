#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_when_a_test_fail_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_a_test_fail_verbose_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --detailed)"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --detailed)"
}

function test_different_verbose_snapshots_matches() {
  bashunit::todo "The different snapshots for these tests should also be identical, option to choose snapshot name?"
}

function test_bashunit_when_a_test_fail_simple_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
}

function test_bashunit_when_a_test_fail_simple_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)"
}

function test_bashunit_with_multiple_failing_tests() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_with_multiple_failing_tests.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)"
}

function test_bashunit_with_a_test_fail_and_exit_immediately() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_exit_immediately_after_execution_error.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)"
}

function test_different_simple_snapshots_matches() {
  bashunit::todo "The different snapshots for these tests should also be identical, option to choose snapshot name?"
}
