#!/usr/bin/env bash

# This file provides a facade to developers who wants
# to interact with the internals of bashunit.
# e.g. adding custom assertions

function bashunit::assertion_failed() {
  bashunit::assert::should_skip && return 0

  local expected=$1
  local actual=$2
  local failure_condition_message=${3:-"but got "}

  bashunit::assert::fail_with "" "${expected}" \
    "$failure_condition_message" "${actual}"
}

function bashunit::assertion_passed() {
  bashunit::assert::should_skip && return 0

  bashunit::state::add_assertions_passed
}
