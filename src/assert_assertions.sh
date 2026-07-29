#!/usr/bin/env bash

# Assertions about assertions: they let a custom assertion be tested for the
# verdict it reports, without reconstructing the expected string from
# bashunit::console_results::print_failed_test.

_BASHUNIT_ASSERT_INNER_FAILED_OUT=0
_BASHUNIT_ASSERT_INNER_PASSED_OUT=0

# Public: the message the last captured assertion reported, colour-stripped and
# flattened to a single line. Set by every assert_assertion_* call, so a test can
# assert on what an assertion did *not* say, which no assertion can express.
_BASHUNIT_ASSERT_INNER_OUTPUT_OUT=""

##
# Runs an assertion in isolation and reports what it did, without letting it
# touch the calling test.
#
# Everything the inner assertion reports is snapshotted and restored: the two
# counters, the stop-on-assertion-failure guard (src/assert.sh:10) — which
# would otherwise make every later assertion in the same test skip — plus the
# per-test output accumulator and the TAP line counter that
# console_results::print_line feeds. Console output is redirected away.
#
# The captured message is read back from that accumulator rather than from
# stdout, because in --simple mode print_line only emits a one-char marker.
#
# Every slot is written *after* the call returns, which is what makes this
# reentrant: a nested capture clobbers the slots while it runs, and the outer
# frame overwrites them again on the way out.
#
# Writes: _BASHUNIT_ASSERT_INNER_FAILED_OUT (1 when it reported a failure),
#         _BASHUNIT_ASSERT_INNER_PASSED_OUT (1 when it reported a success),
#         _BASHUNIT_ASSERT_INNER_OUTPUT_OUT (what it reported).
# Arguments: $1.. - the assertion and its arguments
##
function bashunit::assert::_capture() {
  local before_passed=$_BASHUNIT_ASSERTIONS_PASSED
  local before_failed=$_BASHUNIT_ASSERTIONS_FAILED
  local before_guard=$_BASHUNIT_ASSERTION_FAILED_IN_TEST
  local before_output=$_BASHUNIT_TEST_OUTPUT
  local before_count=$_BASHUNIT_TOTAL_TESTS_COUNT

  # Run the inner assertion unguarded: had an earlier assertion in this test
  # failed, it would otherwise skip and report no verdict at all.
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=0

  "$@" >/dev/null 2>&1 || true

  bashunit::str::strip_ansi_to_slot "${_BASHUNIT_TEST_OUTPUT#"$before_output"}"
  local output=$_BASHUNIT_STR_STRIPPED_OUT

  if [ "$_BASHUNIT_ASSERTIONS_FAILED" -gt "$before_failed" ]; then
    _BASHUNIT_ASSERT_INNER_FAILED_OUT=1
  else
    _BASHUNIT_ASSERT_INNER_FAILED_OUT=0
  fi

  if [ "$_BASHUNIT_ASSERTIONS_PASSED" -gt "$before_passed" ]; then
    _BASHUNIT_ASSERT_INNER_PASSED_OUT=1
  else
    _BASHUNIT_ASSERT_INNER_PASSED_OUT=0
  fi

  _BASHUNIT_ASSERT_INNER_OUTPUT_OUT=$output

  _BASHUNIT_ASSERTIONS_PASSED=$before_passed
  _BASHUNIT_ASSERTIONS_FAILED=$before_failed
  _BASHUNIT_ASSERTION_FAILED_IN_TEST=$before_guard
  _BASHUNIT_TEST_OUTPUT=$before_output
  _BASHUNIT_TOTAL_TESTS_COUNT=$before_count
}

_BASHUNIT_ASSERT_INNER_OUTCOME_OUT=""

# Describes what the captured assertion actually reported, so the failure block
# distinguishes "it passed" from "it never counted an assertion at all".
function bashunit::assert::_inner_outcome_to_slot() {
  if [ "$_BASHUNIT_ASSERT_INNER_FAILED_OUT" -eq 1 ]; then
    _BASHUNIT_ASSERT_INNER_OUTCOME_OUT="a failing assertion"
  elif [ "$_BASHUNIT_ASSERT_INNER_PASSED_OUT" -eq 1 ]; then
    _BASHUNIT_ASSERT_INNER_OUTCOME_OUT="a passing assertion"
  else
    _BASHUNIT_ASSERT_INNER_OUTCOME_OUT="no assertion at all"
  fi
}

##
# Asserts that the given assertion reports a failure.
# Arguments: $1.. - the assertion and its arguments
# Returns: 0 when it failed, 1 otherwise
##
function assert_assertion_fails() {
  bashunit::assert::should_skip && return 0

  bashunit::assert::_capture "$@"

  if [ "$_BASHUNIT_ASSERT_INNER_FAILED_OUT" -eq 1 ]; then
    bashunit::state::add_assertions_passed
    return 0
  fi

  bashunit::assert::_inner_outcome_to_slot
  bashunit::assert::fail_with "" "${1-}" \
    "to be a failing assertion, but got " "$_BASHUNIT_ASSERT_INNER_OUTCOME_OUT"
  return 1
}

##
# Asserts that the given assertion reports a success.
# Arguments: $1.. - the assertion and its arguments
# Returns: 0 when it passed, 1 otherwise
##
function assert_assertion_passes() {
  bashunit::assert::should_skip && return 0

  bashunit::assert::_capture "$@"

  if [ "$_BASHUNIT_ASSERT_INNER_PASSED_OUT" -eq 1 ] &&
    [ "$_BASHUNIT_ASSERT_INNER_FAILED_OUT" -eq 0 ]; then
    bashunit::state::add_assertions_passed
    return 0
  fi

  bashunit::assert::_inner_outcome_to_slot
  bashunit::assert::fail_with "" "${1-}" \
    "to be a passing assertion, but got " "$_BASHUNIT_ASSERT_INNER_OUTCOME_OUT"
  return 1
}

##
# Asserts that the given assertion fails *and* that its failure output contains
# the expected message, so the output contract is testable without reaching into
# bashunit::console_results.
# Arguments: $1 - expected substring of the failure output,
#            $2.. - the assertion and its arguments
# Returns: 0 when it failed with that message, 1 otherwise
##
function assert_assertion_fails_with() {
  bashunit::assert::should_skip && return 0

  local expected_message=$1
  shift

  bashunit::assert::_capture "$@"

  if [ "$_BASHUNIT_ASSERT_INNER_FAILED_OUT" -ne 1 ]; then
    bashunit::assert::_inner_outcome_to_slot
    bashunit::assert::fail_with "" "${1-}" \
      "to be a failing assertion, but got " "$_BASHUNIT_ASSERT_INNER_OUTCOME_OUT"
    return 1
  fi

  case "$_BASHUNIT_ASSERT_INNER_OUTPUT_OUT" in
  *"$expected_message"*)
    bashunit::state::add_assertions_passed
    return 0
    ;;
  esac

  bashunit::assert::fail_with "" "$_BASHUNIT_ASSERT_INNER_OUTPUT_OUT" \
    "to contain" "$expected_message"
  return 1
}
