#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_timeout.sh"
}

function test_bashunit_terminates_a_hanging_test_with_timeout() {
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 1 "$FIXTURE")" || true

  assert_contains "Test timed out after 1s" "$output"
}

function test_bashunit_keeps_running_tests_after_a_timed_out_one() {
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 1 "$FIXTURE")" || true

  # The fast test still ran and passed and the run reached its summary instead
  # of hanging forever on the blocked test.
  assert_contains "1 passed" "$output"
  assert_contains "1 failed" "$output"
}

function test_bashunit_returns_error_when_a_test_times_out() {
  assert_general_error \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 1 "$FIXTURE")"
}

function test_bashunit_does_not_time_out_a_fast_test() {
  local fast_only=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_successful_code \
    "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --test-timeout 5 "$fast_only")"
}
