#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_PATH="tests/acceptance/fixtures/tests_path"
}

function test_bashunit_count_option() {
  assert_same "4" "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --count "$TEST_PATH")"
  assert_successful_code "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --count "$TEST_PATH")"
}
