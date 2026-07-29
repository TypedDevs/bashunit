#!/usr/bin/env bash

FIXTURE="tests/acceptance/fixtures/test_assert_once_composed.sh"
TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"

function fixture_summary() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" "$FIXTURE" 2>&1 || true
}

function test_a_composed_assertion_counts_once_per_call() {
  local output
  output=$(fixture_summary)

  # 6 calls to assert_http_success (1 + 1 + 3 in the loop + 1) plus the one
  # plain assert_same, instead of the 13 the inner built-ins would count alone.
  assert_contains "6 passed" "$output"
  assert_contains "1 failed, 7 total" "$output"
}

function test_a_composed_failure_reports_the_custom_label() {
  local output
  output=$(fixture_summary)

  assert_contains "Expected 'a 2xx status'" "$output"
  assert_contains "but got  '500'" "$output"
}

function test_a_composed_failure_is_named_after_the_test_not_the_flush() {
  local output
  output=$(fixture_summary)

  assert_contains "Failed: Composed fails" "$output"
}

function test_a_composed_failure_hides_the_inner_assertion_message() {
  local output
  output=$(fixture_summary)

  assert_not_contains "to be less than" "$output"
}
