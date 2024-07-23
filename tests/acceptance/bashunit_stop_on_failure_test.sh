#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_STOP_ON_FAILURE="tests/acceptance/fixtures/.env.stop_on_failure"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_when_stop_on_failure_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
}

function test_bashunit_when_stop_on_failure_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file")"
}

function test_different_snapshots_matches() {
  todo "The different snapshots for these tests should also be identical to each other, option to choose snapshot name?"
}

function test_bashunit_when_stop_on_failure_env_simple_output() {
  todo "Should print something like .F"
  return

  # shellcheck disable=SC2317
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_stop_on_failure.sh

  # shellcheck disable=SC2317
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file" --simple)"
  # shellcheck disable=SC2317
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_STOP_ON_FAILURE" "$test_file" --simple)"
}
