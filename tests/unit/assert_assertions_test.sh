#!/usr/bin/env bash

# A custom assertion routed through bashunit::fail rather than the counters
# directly, to prove the capture notices that flavour of failure too.
function _assert_never_valid() {
  bashunit::fail "always invalid"
}

function test_assert_assertion_fails_when_the_inner_assertion_fails() {
  assert_assertion_fails assert_same "a" "b"
}

function test_assert_assertion_fails_detects_a_failure_raised_through_bashunit_fail() {
  assert_assertion_fails _assert_never_valid
}

function test_assert_assertion_fails_fails_when_the_inner_assertion_passes() {
  assert_assertion_fails assert_assertion_fails assert_same "a" "a"
}

function test_assert_assertion_fails_fails_when_nothing_is_asserted() {
  assert_assertion_fails assert_assertion_fails true
}

function test_assert_assertion_passes_when_the_inner_assertion_passes() {
  assert_assertion_passes assert_same "a" "a"
}

function test_assert_assertion_passes_fails_when_the_inner_assertion_fails() {
  assert_assertion_fails assert_assertion_passes assert_same "a" "b"
}

function test_assert_assertion_passes_fails_when_nothing_is_asserted() {
  assert_assertion_fails assert_assertion_passes true
}

function test_assert_assertion_fails_with_matches_the_failure_message() {
  assert_assertion_fails_with "but got" assert_same "a" "b"
}

function test_assert_assertion_fails_with_rejects_a_different_message() {
  assert_assertion_fails assert_assertion_fails_with "unrelated text" assert_same "a" "b"
}

function test_assert_assertion_fails_with_fails_when_the_inner_assertion_passes() {
  assert_assertion_fails assert_assertion_fails_with "but got" assert_same "a" "a"
}

function test_assert_assertion_fails_restores_the_assertion_counters() {
  local before_passed=$_BASHUNIT_ASSERTIONS_PASSED
  local before_failed=$_BASHUNIT_ASSERTIONS_FAILED

  assert_assertion_fails assert_same "a" "b"

  # Exactly one assertion is reported: the outer one. The inner failure leaves
  # neither counter behind.
  assert_same "$((before_passed + 1))" "$_BASHUNIT_ASSERTIONS_PASSED"
  assert_same "$before_failed" "$_BASHUNIT_ASSERTIONS_FAILED"
}

function test_assert_assertion_passes_restores_the_assertion_counters() {
  local before_passed=$_BASHUNIT_ASSERTIONS_PASSED
  local before_failed=$_BASHUNIT_ASSERTIONS_FAILED

  assert_assertion_passes assert_same "a" "a"

  assert_same "$((before_passed + 1))" "$_BASHUNIT_ASSERTIONS_PASSED"
  assert_same "$before_failed" "$_BASHUNIT_ASSERTIONS_FAILED"
}

function test_assert_assertion_fails_leaves_the_stop_on_failure_guard_untouched() {
  # Without the restore, the inner failure would set the guard and every later
  # assertion in this test would be silently skipped under
  # BASHUNIT_STOP_ON_FAILURE.
  local before=$_BASHUNIT_ASSERTION_FAILED_IN_TEST

  assert_assertion_fails assert_same "a" "b"

  assert_same "$before" "$_BASHUNIT_ASSERTION_FAILED_IN_TEST"
}

function test_assert_assertion_fails_does_not_print_the_inner_failure() {
  local output
  output="$(assert_assertion_fails assert_same "a" "b")"

  assert_empty "$output"
}

function test_assert_assertion_fails_leaves_the_test_output_accumulator_untouched() {
  # print_line also appends to _BASHUNIT_TEST_OUTPUT, which the runner renders
  # as this test's "Output:" block. Redirecting stdout alone would still leak
  # the inner failure there.
  local before=$_BASHUNIT_TEST_OUTPUT

  assert_assertion_fails assert_same "a" "b"

  assert_same "$before" "$_BASHUNIT_TEST_OUTPUT"
}

function test_assert_assertion_fails_with_reads_the_message_not_the_console_output() {
  # In --simple mode the console only receives a one-char marker, so matching
  # on stdout would make this pass sequentially and fail in CI.
  assert_assertion_fails_with "Expected" assert_same "a" "b"
}

function test_assert_assertion_fails_forwards_every_argument_to_the_assertion() {
  # A boundary-exact assertion proves the arguments are not re-split or eval'd.
  assert_assertion_passes assert_same "one two" "one two"
  assert_assertion_fails assert_same "one two" "one  two"
}
