#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_tap_output_passing_tests_matches_snapshot() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file")"
}

function test_tap_output_failing_tests_matches_snapshot() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file" 2>&1 || true)"
}

function test_tap_output_env_var_equivalent_to_flag() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local via_flag
  local via_env

  via_flag=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file")
  via_env=$(BASHUNIT_OUTPUT_FORMAT=tap ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")

  assert_equals "$via_flag" "$via_env"
}

function test_tap_output_exits_non_zero_on_failure() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --output tap "$test_file" 2>&1)"
}
