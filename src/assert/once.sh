#!/usr/bin/env bash

# Opt-in marker: a custom assertion built from built-in assertions otherwise
# reports one assertion per inner step, and its failure names the step rather
# than itself. Declaring bashunit::assert_once absorbs them all into one.
#
# Opt-in because bash has no cheap hook on a user function's return, and the
# inner assertions are siblings, not nested frames -- nothing to detect without
# a functrace RETURN trap on the per-test hot path. It also leaves existing
# suites' totals untouched.
#
# With no return hook, the marker counts one pass immediately and the flush
# converts it to a failure if anything it absorbed failed, so the totals are
# correct at every point in time.
#
# Flushed by whichever comes first: the next assert_once call (which is what
# makes a loop count once per iteration), an assertion after the declaring frame
# returned, or runner::cleanup_on_exit at end of test.

_BASHUNIT_ASSERT_ONCE_ACTIVE=0
_BASHUNIT_ASSERT_ONCE_FRAME=""
_BASHUNIT_ASSERT_ONCE_ABS=0
_BASHUNIT_ASSERT_ONCE_LABEL=""
_BASHUNIT_ASSERT_ONCE_ACTUAL=""
_BASHUNIT_ASSERT_ONCE_FAILED=0
_BASHUNIT_ASSERT_ONCE_IN_EXPECTED=""
_BASHUNIT_ASSERT_ONCE_IN_CONDITION=""
_BASHUNIT_ASSERT_ONCE_IN_ACTUAL=""
# Name of the test that opened the marker, resolved while its frame is still on
# the stack. The end-of-test flush runs from the EXIT trap, where it is not.
_BASHUNIT_ASSERT_ONCE_TEST_LABEL=""

##
# Whether an inner assertion should be absorbed by an open marker right now.
# Closes the marker when the frame that declared it has already returned.
# Returns: 0 while absorbing, 1 otherwise
##
function bashunit::assert::once_is_absorbing() {
  [ "$_BASHUNIT_ASSERT_ONCE_ACTIVE" -eq 1 ] || return 1

  # The declaring frame was recorded by its distance from the bottom of the
  # stack, so the lookup stays valid however deep the inner assertions nest.
  local index=$((${#FUNCNAME[@]} - _BASHUNIT_ASSERT_ONCE_ABS))
  if [ "$index" -ge 0 ] &&
    [ "${FUNCNAME[$index]-}" = "$_BASHUNIT_ASSERT_ONCE_FRAME" ]; then
    return 0
  fi

  bashunit::assert::once_flush
  return 1
}

##
# Records the first absorbed failure message, kept as the fallback for a marker
# that declared no label of its own.
# Arguments: $1 - expected, $2 - failure condition message, $3 - actual
##
function bashunit::assert::once_absorb_message() {
  _BASHUNIT_ASSERT_ONCE_FAILED=1

  if [ -n "$_BASHUNIT_ASSERT_ONCE_IN_EXPECTED$_BASHUNIT_ASSERT_ONCE_IN_ACTUAL" ]; then
    return 0
  fi

  _BASHUNIT_ASSERT_ONCE_IN_EXPECTED=${1-}
  _BASHUNIT_ASSERT_ONCE_IN_CONDITION=${2-}
  _BASHUNIT_ASSERT_ONCE_IN_ACTUAL=${3-}
}

##
# Settles an open marker: reports its single failure if anything it absorbed
# failed, otherwise leaves the optimistic pass counted at declaration time.
# Safe to call with no marker open.
##
function bashunit::assert::once_flush() {
  [ "$_BASHUNIT_ASSERT_ONCE_ACTIVE" -eq 1 ] || return 0

  # Close first: the reporting below goes through the ordinary assertion
  # machinery and must not be absorbed by the marker it is closing.
  _BASHUNIT_ASSERT_ONCE_ACTIVE=0

  if [ "$_BASHUNIT_ASSERT_ONCE_FAILED" -eq 0 ]; then
    return 0
  fi

  # Undo the optimistic pass taken at declaration time.
  _BASHUNIT_ASSERTIONS_PASSED=$((_BASHUNIT_ASSERTIONS_PASSED - 1))

  local expected=$_BASHUNIT_ASSERT_ONCE_LABEL
  local condition="but got "
  local actual=$_BASHUNIT_ASSERT_ONCE_ACTUAL

  # With no label of its own, fall back to the innermost failure, which is
  # exactly what bashunit reports today.
  if [ -z "$expected" ]; then
    expected=$_BASHUNIT_ASSERT_ONCE_IN_EXPECTED
    condition=$_BASHUNIT_ASSERT_ONCE_IN_CONDITION
    actual=$_BASHUNIT_ASSERT_ONCE_IN_ACTUAL
  fi

  bashunit::assert::fail_with \
    "$_BASHUNIT_ASSERT_ONCE_TEST_LABEL" "$expected" "$condition" "$actual"
}

# Clears any marker so it cannot leak from one test into the next.
function bashunit::assert::once_reset() {
  _BASHUNIT_ASSERT_ONCE_ACTIVE=0
  _BASHUNIT_ASSERT_ONCE_FRAME=""
  _BASHUNIT_ASSERT_ONCE_ABS=0
  _BASHUNIT_ASSERT_ONCE_LABEL=""
  _BASHUNIT_ASSERT_ONCE_ACTUAL=""
  _BASHUNIT_ASSERT_ONCE_FAILED=0
  _BASHUNIT_ASSERT_ONCE_IN_EXPECTED=""
  _BASHUNIT_ASSERT_ONCE_IN_CONDITION=""
  _BASHUNIT_ASSERT_ONCE_IN_ACTUAL=""
  _BASHUNIT_ASSERT_ONCE_TEST_LABEL=""
}

##
# Declares that the calling custom assertion counts and reports as one
# assertion, whatever it asserts internally.
# Arguments: $1 - label shown in the failure block (optional; without it the
#                 innermost failure message is reported, as it is today),
#            $2 - actual value shown against that label (optional)
##
function bashunit::assert_once() {
  bashunit::assert::should_skip && return 0

  # Settle a marker left open by a sibling call or by the previous iteration of
  # a loop over the same custom assertion.
  bashunit::assert::once_flush

  bashunit::assert::once_reset

  _BASHUNIT_ASSERT_ONCE_LABEL=${1-}
  _BASHUNIT_ASSERT_ONCE_ACTUAL=${2-}

  # Count now, convert on flush: see the note at the top of this file.
  bashunit::state::add_assertions_passed

  # Resolved here, while the test frame is still on the stack: the end-of-test
  # flush runs from the EXIT trap, which would otherwise label the failure with
  # the flushing function's own name.
  bashunit::assert::label_to_slot ""
  _BASHUNIT_ASSERT_ONCE_TEST_LABEL=$_BASHUNIT_ASSERT_LABEL_OUT

  _BASHUNIT_ASSERT_ONCE_FRAME=${FUNCNAME[1]-}
  _BASHUNIT_ASSERT_ONCE_ABS=$((${#FUNCNAME[@]} - 1))
  _BASHUNIT_ASSERT_ONCE_ACTIVE=1
}
