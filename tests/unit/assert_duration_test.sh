#!/usr/bin/env bash
# shellcheck disable=SC2329

function test_successful_assert_duration_within() {
  assert_empty "$(assert_duration "sleep 0" 5000)"
}

function test_successful_assert_duration_within_fast_command() {
  assert_empty "$(assert_duration "echo hello" 5000)"
}

# Failure paths mock bashunit::duration::measure_ms: they exercise the
# threshold comparison and failure message, not the timing itself, so a real
# `sleep 1` per test only slowed the suite down (#826).
function test_unsuccessful_assert_duration_exceeds_threshold() {
  bashunit::mock bashunit::duration::measure_ms <<<"2000"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert duration exceeds threshold" \
      "1000" "to complete within (ms)" "fake_slow_command")" \
    "$(assert_duration "fake_slow_command" 1000)"
}

function test_successful_assert_duration_less_than() {
  assert_empty "$(assert_duration_less_than "sleep 0" 5000)"
}

function test_unsuccessful_assert_duration_less_than() {
  bashunit::mock bashunit::duration::measure_ms <<<"2000"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert duration less than" \
      "100" "to complete within (ms)" "fake_slow_command")" \
    "$(assert_duration_less_than "fake_slow_command" 100)"
}

# Keep one success path on a real (short) sleep so measure_ms integration
# stays covered end-to-end. The last-resort date-seconds clock has 1s
# resolution and would measure a sub-second sleep as 0ms, so skip there.
function test_successful_assert_duration_greater_than() {
  bashunit::clock::now_to_slot >/dev/null 2>&1 || true
  if [ "${_BASHUNIT_CLOCK_NOW_IMPL:-}" = "date-seconds" ]; then
    bashunit::skip "clock has 1s resolution" && return
  fi

  assert_empty "$(assert_duration_greater_than "sleep 0.2" 100)"
}

function test_unsuccessful_assert_duration_greater_than() {
  bashunit::mock bashunit::duration::measure_ms <<<"3"

  assert_same \
    "$(bashunit::console_results::print_failed_test \
      "Unsuccessful assert duration greater than" \
      "5000" "to take at least (ms)" "fake_fast_command")" \
    "$(assert_duration_greater_than "fake_fast_command" 5000)"
}
