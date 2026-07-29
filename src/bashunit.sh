#!/usr/bin/env bash

# This file provides a facade to developers who wants
# to interact with the internals of bashunit.
# e.g. adding custom assertions

##
# Marks the current assertion as failed and prints the standard failure block.
# Arguments: $1 - expected, $2 - actual, $3 - failure condition message
#            (optional, default: "but got "), $4 - label naming the assertion in
#            the failure block (optional, defaults to the test function name)
##
function bashunit::assertion_failed() {
  bashunit::assert::should_skip && return 0

  local expected=$1
  local actual=$2
  local failure_condition_message=${3:-"but got "}
  local label=${4:-}

  bashunit::assert::fail_with "$label" "${expected}" \
    "$failure_condition_message" "${actual}"
}

function bashunit::assertion_passed() {
  bashunit::assert::should_skip && return 0

  bashunit::state::add_assertions_passed
}

##
# Runs a command and marks the assertion passed or failed accordingly, so a
# custom assertion cannot desync the passed/failed counters by forgetting to
# `return` after a failure or to mark a success.
# Arguments: $1 - expected (described for the failure block), $2 - actual,
#            $3.. - the command and its arguments
# Returns: 0 when the command succeeds, 1 otherwise
##
function bashunit::assert_that() {
  bashunit::assert::should_skip && return 0

  local expected=$1
  local actual=$2
  shift 2

  if "$@"; then
    bashunit::state::add_assertions_passed
    return 0
  fi

  bashunit::assert::fail_with "" "$expected" "but got " "$actual"
  return 1
}
