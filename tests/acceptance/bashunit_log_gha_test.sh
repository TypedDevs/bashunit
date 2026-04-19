#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_BASHUNIT_LOG_GHA="tests/acceptance/fixtures/.env.log_gha"
}

function test_bashunit_when_log_gha_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --log-gha custom.log "$test_file" >/dev/null

  assert_file_exists custom.log
  assert_contains "::error file=$test_file" "$(cat custom.log)"
  assert_contains "title=Failure" "$(cat custom.log)"
  rm custom.log
}

function test_bashunit_when_log_gha_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  ./bashunit --no-parallel --env "$TEST_ENV_FILE_BASHUNIT_LOG_GHA" "$test_file" >/dev/null

  assert_file_exists log-gha.txt
  assert_contains "::error" "$(cat log-gha.txt)"
  rm log-gha.txt
}
