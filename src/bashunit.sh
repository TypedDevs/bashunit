#!/usr/bin/env bash

# This file provides a facade to developers who wants
# to interact with the internals of bashunit.
# e.g. adding custom assertions

function bashunit::assertion_failed() {
  local expected=$1
  local actual=$2
  local failure_condition_message=${3:-"but got "}

  local label
  label="$(helper::normalize_test_function_name "${FUNCNAME[2]}")"
  state::add_assertions_failed
  console_results::print_failed_test "${label}" "${expected}" \
    "$failure_condition_message" "${actual}"
}

function bashunit::assertion_passed() {
  state::add_assertions_passed
}
