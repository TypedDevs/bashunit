#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_profile_flag_prints_slowest_tests_header() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --profile "$test_file")"

  assert_contains "Slowest tests" "$output"
  assert_contains "test_assert_same" "$output"
}

function test_profile_flag_is_off_by_default() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")"

  assert_not_contains "Slowest tests" "$output"
}

function test_profile_flag_works_in_parallel() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output
  output="$(./bashunit --parallel --env "$TEST_ENV_FILE" --profile "$test_file")"

  assert_contains "Slowest tests" "$output"
}
