#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_LOG_JUNIT="tests/acceptance/fixtures/.env.stop_on_failure"
}

function test_bashunit_when_log_junit() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
}

function test_bashunit_when_stop_on_failure_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_LOG_JUNIT" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_LOG_JUNIT" "$test_file")"
}
