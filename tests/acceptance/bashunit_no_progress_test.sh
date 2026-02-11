#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_no_progress_suppresses_test_output_in_detailed_mode() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-progress "$test_file" 2>&1)

  # Should NOT contain "Passed" (per-test progress output)
  assert_not_contains "Passed" "$output"
  # Should still show final summary
  assert_contains "Tests:" "$output"
  assert_contains "4 passed" "$output"
}

function test_no_progress_suppresses_test_output_in_simple_mode() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" --no-progress "$test_file" 2>&1)

  # Should NOT contain dots for passed tests
  assert_not_contains "...." "$output"
  # Should still show final summary
  assert_contains "Tests:" "$output"
  assert_contains "4 passed" "$output"
}

function test_no_progress_suppresses_file_headers() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-progress "$test_file" 2>&1)

  # Should NOT contain "Running" file headers
  assert_not_contains "Running" "$output"
}

function test_no_progress_shows_correct_counts_in_summary() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-progress "$test_file" 2>&1)

  # Summary should show passed count even though progress was suppressed
  assert_contains "4 passed" "$output"
  assert_contains "4 total" "$output"
}

function test_no_progress_still_shows_failures_in_summary() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
  local output

  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --no-progress "$test_file" 2>&1) || true

  # Should still show failure summary
  assert_contains "There was 1 failure" "$output"
  assert_contains "Tests:" "$output"
}

function test_no_progress_via_env_variable() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output

  output=$(BASHUNIT_NO_PROGRESS=true ./bashunit --no-parallel --skip-env-file "$test_file" 2>&1)

  assert_not_contains "Passed" "$output"
  assert_contains "4 passed" "$output"
}
