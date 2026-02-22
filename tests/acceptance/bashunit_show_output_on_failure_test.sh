#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_show_output_on_failure_enabled_by_default() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_show_output_on_failure.sh

  local actual
  actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" 2>&1 || true)"

  assert_contains "Output:" "$actual"
  assert_contains "Debug: Starting test" "$actual"
  assert_contains "Info: About to run command" "$actual"
}

function test_show_output_on_failure_disabled_via_flag() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_show_output_on_failure.sh

  local actual
  actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-output-on-failure "$test_file" 2>&1 || true)"

  assert_not_contains "Output:" "$actual"
  assert_not_contains "Debug: Starting test" "$actual"
}

function test_show_output_on_failure_disabled_via_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_show_output_on_failure.sh

  local actual
  actual="$(
    BASHUNIT_SHOW_OUTPUT_ON_FAILURE=false \
      ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" 2>&1 || true
  )"

  assert_not_contains "Output:" "$actual"
  assert_not_contains "Debug: Starting test" "$actual"
}

function test_show_output_flag_overrides_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_show_output_on_failure.sh

  local actual
  actual="$(
    BASHUNIT_SHOW_OUTPUT_ON_FAILURE=false \
      ./bashunit --no-parallel --env "$TEST_ENV_FILE" --show-output "$test_file" 2>&1 || true
  )"

  assert_contains "Output:" "$actual"
  assert_contains "Debug: Starting test" "$actual"
}
