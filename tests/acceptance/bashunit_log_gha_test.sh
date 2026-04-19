#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_BASHUNIT_LOG_GHA="tests/acceptance/fixtures/.env.log_gha"
}

function test_bashunit_when_log_gha_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh
  local log_file
  log_file=$(mktemp "${TMPDIR:-/tmp}/bashunit-gha-opt.XXXXXX")

  # Inner suite has a failing test, so bashunit exits nonzero; tolerate it
  # so the acceptance test keeps running under --strict (set -e).
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --log-gha "$log_file" "$test_file" >/dev/null || true

  assert_file_exists "$log_file"
  assert_contains "::error file=$test_file" "$(cat "$log_file")"
  assert_contains "title=Failure" "$(cat "$log_file")"
  rm -f "$log_file"
}

function test_bashunit_when_log_gha_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  ./bashunit --no-parallel --env "$TEST_ENV_FILE_BASHUNIT_LOG_GHA" "$test_file" >/dev/null || true

  assert_file_exists log-gha.txt
  assert_contains "::error" "$(cat log-gha.txt)"
  rm -f log-gha.txt
}
