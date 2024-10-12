#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_BASHUNIT_LOG_JUNIT="tests/acceptance/fixtures/.env.log_junit"
}

function test_bashunit_when_log_junit_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --log-junit custom.xml "$test_file")"
  assert_file_exists custom.xml
  rm custom.xml
}

function test_bashunit_when_log_junit_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_BASHUNIT_LOG_JUNIT" "$test_file")"
  assert_file_exists log-junit.xml
  rm log-junit.xml
}
