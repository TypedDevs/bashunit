#!/bin/bash

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_LOG_JUNIT="tests/acceptance/fixtures/.env.log_junit"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_when_log_junit_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" --log-junit custom.xml "$test_file")"
  assert_file_exists custom.xml
  rm custom.xml
}

function test_bashunit_when_log_junit_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_LOG_JUNIT" "$test_file")"
  assert_file_exists log-junit.xml
  rm log-junit.xml
}
