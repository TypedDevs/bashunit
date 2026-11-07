#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_skipped_and_incomplete.sh"
}

function test_skipped_tests_not_displayed_without_flag() {
  local output
  output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" "$FIXTURE" 2>&1) || true

  assert_not_contains "There was 1 skipped test:" "$output"
}

function test_incomplete_tests_not_displayed_without_flag() {
  local output
  output=$(./bashunit --no-parallel --simple --env "$TEST_ENV_FILE" "$FIXTURE" 2>&1) || true

  assert_not_contains "There was 1 incomplete test:" "$output"
}

function test_skipped_tests_displayed_with_show_skipped_flag() {
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel --simple --show-skipped "$FIXTURE" 2>&1) || true

  assert_contains "There was 1 skipped test:" "$output"
  assert_contains "Skips on purpose" "$output"
  assert_not_contains "incomplete test" "$output"
}

function test_incomplete_tests_displayed_with_show_incomplete_flag() {
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel --simple --show-incomplete "$FIXTURE" 2>&1) || true

  assert_contains "There was 1 incomplete test:" "$output"
  assert_contains "Is not done yet" "$output"
  assert_not_contains "skipped test" "$output"
}

function test_both_flags_can_be_used_together() {
  local output
  output=$(./bashunit --env "$TEST_ENV_FILE" --no-parallel --simple --show-skipped --show-incomplete \
    "$FIXTURE" 2>&1) || true

  assert_contains "There was 1 incomplete test:" "$output"
  assert_contains "There was 1 skipped test:" "$output"
}
