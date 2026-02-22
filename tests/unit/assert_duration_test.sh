#!/usr/bin/env bash
# shellcheck disable=SC2329

function test_successful_assert_duration_within() {
  assert_empty "$(assert_duration "sleep 0" 5000)"
}

function test_successful_assert_duration_within_fast_command() {
  assert_empty "$(assert_duration "echo hello" 5000)"
}

function test_unsuccessful_assert_duration_exceeds_threshold() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert duration exceeds threshold" \
      "1000" "to complete within (ms)" "sleep 1")" \
    "$(assert_duration "sleep 1" 1000)"
}

function test_successful_assert_duration_less_than() {
  assert_empty "$(assert_duration_less_than "sleep 0" 5000)"
}

function test_unsuccessful_assert_duration_less_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert duration less than" \
      "100" "to complete within (ms)" "sleep 1")" \
    "$(assert_duration_less_than "sleep 1" 100)"
}

function test_successful_assert_duration_greater_than() {
  assert_empty "$(assert_duration_greater_than "sleep 1" 500)"
}

function test_unsuccessful_assert_duration_greater_than() {
  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert duration greater than" \
      "5000" "to take at least (ms)" "echo hello")" \
    "$(assert_duration_greater_than "echo hello" 5000)"
}
