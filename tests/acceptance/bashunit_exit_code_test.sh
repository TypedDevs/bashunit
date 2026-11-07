#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_a_test_returns_non_zero() {
  local test_file=tests/acceptance/fixtures/test_bashunit_when_a_test_returns_non_zero.sh

  local output exit_code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")" || exit_code=$?
  assert_match_snapshot "$output"
  assert_general_error "" "" "$exit_code"
}
