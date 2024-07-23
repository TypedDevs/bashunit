#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_a_test_passes_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_total_tests_test.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
}
