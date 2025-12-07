#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_no_output_success() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --no-output)
  assert_successful_code "$output"
  assert_empty "$output"
}

function test_bashunit_no_output_failure() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
  local output
  local exit_code=0
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --no-output) || exit_code=$?
  assert_same 1 "$exit_code"
  assert_empty "$output"
}
