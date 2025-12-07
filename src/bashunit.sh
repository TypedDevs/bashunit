#!/usr/bin/env bash

# This file provides a facade to developers who wants
# to interact with the internals of bashunit.
# e.g. adding custom assertions

function bashunit::assertion_failed() {
  (( _BASHUNIT_ASSERTION_FAILED_IN_TEST )) && return 0

  local expected=$1
  local actual=$2
  local failure_condition_message=${3:-"but got "}

  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  assert::mark_failed
  console_results::print_failed_test "${label}" "${expected}" \
    "$failure_condition_message" "${actual}"
}

function bashunit::assertion_passed() {
  (( _BASHUNIT_ASSERTION_FAILED_IN_TEST )) && return 0

  state::add_assertions_passed
}
