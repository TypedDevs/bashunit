#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_RUN_ALL="tests/acceptance/fixtures/.env.run_all_assertions"
}

function test_default_behavior_stops_on_first_assertion_failure() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_run_all_assertions.sh

  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" 2>&1)" || true

  # Default: should only show first failure per test (2 failures: one from each failing test)
  # test_multiple_failures_with_run_all: 1 failure shown
  # test_pass_after_failure: 1 failure shown
  # test_all_pass: 0 failures
  assert_contains "2 failed" "$output"
}

function test_run_all_flag_shows_all_assertion_failures() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_run_all_assertions.sh

  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --run-all "$test_file" 2>&1)" || true

  # With --run-all: should show all failures
  # test_multiple_failures_with_run_all: 3 failures shown
  # test_pass_after_failure: 1 failure shown
  # test_all_pass: 0 failures
  assert_contains "4 failed" "$output"
}

function test_run_all_short_flag() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_run_all_assertions.sh

  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" -R "$test_file" 2>&1)" || true

  # With -R: same as --run-all, should show all failures
  assert_contains "4 failed" "$output"
}

function test_run_all_via_env_variable() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_run_all_assertions.sh

  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_RUN_ALL" "$test_file" 2>&1)" || true

  # With env var: should show all failures
  assert_contains "4 failed" "$output"
}
