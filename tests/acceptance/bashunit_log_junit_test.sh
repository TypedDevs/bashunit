#!/usr/bin/env bash

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

function test_bashunit_report_junit_is_alias_of_log_junit() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  # The fixture contains failing tests by design, so the run exits non-zero;
  # swallow it (we only care that --report-junit produced the file).
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-junit report-junit-alias.xml "$test_file" >/dev/null 2>&1 || true
  assert_file_exists report-junit-alias.xml
  assert_file_contains report-junit-alias.xml "<testsuite"
  rm report-junit-alias.xml
}
