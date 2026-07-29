#!/usr/bin/env bash

function assert_http_success() {
  bashunit::assert_once "a 2xx status" "$1"

  assert_greater_or_equal_than "200" "$1"
  assert_less_than "300" "$1"
}

function test_assert_once_counts_a_passing_composed_assertion_once() {
  local counters
  counters="$(
    _BASHUNIT_ASSERTIONS_PASSED=0
    _BASHUNIT_ASSERTIONS_FAILED=0
    assert_http_success 200
    bashunit::assert::once_flush
    echo "$_BASHUNIT_ASSERTIONS_PASSED:$_BASHUNIT_ASSERTIONS_FAILED"
  )"

  assert_same "1:0" "$counters"
}

function test_assert_once_counts_a_failing_composed_assertion_once() {
  local counters
  counters="$(
    # shellcheck disable=SC2317,SC2329
    bashunit::console_results::print_line() { :; }
    _BASHUNIT_ASSERTIONS_PASSED=0
    _BASHUNIT_ASSERTIONS_FAILED=0
    _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
    assert_http_success 500
    bashunit::assert::once_flush
    echo "$_BASHUNIT_ASSERTIONS_PASSED:$_BASHUNIT_ASSERTIONS_FAILED"
  )"

  assert_same "0:1" "$counters"
}

function test_assert_once_counts_every_call_when_looped() {
  # Re-entering the declaring frame flushes the previous call, so calls from
  # the same source line are not merged.
  local counters
  counters="$(
    _BASHUNIT_ASSERTIONS_PASSED=0
    _BASHUNIT_ASSERTIONS_FAILED=0
    local code
    for code in 200 201 204; do
      assert_http_success "$code"
    done
    bashunit::assert::once_flush
    echo "$_BASHUNIT_ASSERTIONS_PASSED:$_BASHUNIT_ASSERTIONS_FAILED"
  )"

  assert_same "3:0" "$counters"
}

function test_assert_once_stops_absorbing_once_the_declaring_frame_returns() {
  local counters
  counters="$(
    _BASHUNIT_ASSERTIONS_PASSED=0
    _BASHUNIT_ASSERTIONS_FAILED=0
    assert_http_success 200
    assert_same "a" "a"
    bashunit::assert::once_flush
    echo "$_BASHUNIT_ASSERTIONS_PASSED:$_BASHUNIT_ASSERTIONS_FAILED"
  )"

  assert_same "2:0" "$counters"
}

function test_assert_once_reports_the_custom_label_not_the_inner_message() {
  assert_assertion_fails_with "a 2xx status" assert_http_success 500

  assert_not_contains "to be less than" "$_BASHUNIT_ASSERT_INNER_OUTPUT_OUT"
}

function test_assert_once_does_not_leak_into_assert_assertion_helpers() {
  # The isolation capture must neutralise an active marker, otherwise a custom
  # assertion under test would swallow the verdict the capture reads back.
  assert_assertion_passes assert_http_success 200
  assert_assertion_fails assert_http_success 500
}

function test_assert_once_leaves_the_stop_on_failure_guard_for_the_flush() {
  local guard
  guard="$(
    # shellcheck disable=SC2317,SC2329
    bashunit::console_results::print_line() { :; }
    _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
    assert_http_success 500
    # Absorbed inner failures must not arm the guard before the flush decides.
    local during=$_BASHUNIT_ASSERTION_FAILED_IN_TEST
    bashunit::assert::once_flush
    echo "$during:$_BASHUNIT_ASSERTION_FAILED_IN_TEST"
  )"

  assert_same "0:1" "$guard"
}
