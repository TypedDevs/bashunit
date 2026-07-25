#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_FILE="tests/acceptance/fixtures/tests_path/a_test.sh"
}

# The numeric options used to accept any string. `[ n -lt abc ]` errors rather
# than returning false, so the value was either ignored or -- on the Bash 3.x
# job-slot poll -- looped forever (#873).
function test_bashunit_fails_when_jobs_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--jobs" "$output"
}

function test_bashunit_fails_when_jobs_is_negative() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs -5 "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
}

function test_bashunit_fails_when_retry_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --retry abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--retry" "$output"
}

function test_bashunit_fails_when_test_timeout_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --test-timeout abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--test-timeout" "$output"
}

function test_bashunit_fails_when_coverage_min_is_not_a_number() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --coverage-min abc "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--coverage-min" "$output"
}

function test_bashunit_fails_when_output_format_is_unsupported() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --output nonsense "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--output" "$output"
}

# The environment path bypasses flag parsing entirely, so it needs the same gate.
function test_bashunit_fails_when_parallel_jobs_env_var_is_not_a_number() {
  local ec=0
  local output
  output=$(BASHUNIT_PARALLEL_JOBS=abc ./bashunit --env "$TEST_ENV_FILE" --parallel "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_PARALLEL_JOBS" "$output"
}

# BASHUNIT_COVERAGE_THRESHOLD_LOW/HIGH are env-only (no CLI flag) and are
# compared with `[ -ge ]` in bashunit::coverage::get_coverage_class. A
# non-integer value used to leak a raw "integer expression expected" shell
# error into the coverage report and silently mis-bucket every file's
# high/medium/low class instead of failing fast (#879).
function test_bashunit_fails_when_coverage_threshold_high_env_var_is_not_a_number() {
  local ec=0
  local output
  # --skip-env-file is required: .env / .env.example both list these two names,
  # and an allexport `source .env` turns an empty listing into an unconditional
  # assignment that overrides the exported value under test (#865).
  output=$(BASHUNIT_COVERAGE_THRESHOLD_HIGH=abc ./bashunit --skip-env-file --coverage "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_COVERAGE_THRESHOLD_HIGH" "$output"
}

function test_bashunit_fails_when_coverage_threshold_low_env_var_is_not_a_number() {
  local ec=0
  local output
  # See the note above: .env would otherwise override the value under test.
  output=$(BASHUNIT_COVERAGE_THRESHOLD_LOW=abc ./bashunit --skip-env-file --coverage "$TEST_FILE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_COVERAGE_THRESHOLD_LOW" "$output"
}

function test_bashunit_still_accepts_valid_option_values() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs 2 --retry 0 --test-timeout 0 "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}

function test_bashunit_still_accepts_jobs_auto() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --jobs auto "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "All tests passed" "$output"
}

function test_bashunit_still_accepts_tap_output() {
  local ec=0
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --output tap "$TEST_FILE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "TAP version 13" "$output"
}
