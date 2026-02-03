#!/usr/bin/env bash

function assert_array_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  shift

  # Bash 3.0 compatible array initialization
  local actual; [[ $# -gt 0 ]] && actual=("$@")

  if ! [[ "${actual[*]:-}" == *"$expected"* ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_array_not_contains() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  shift
  # Bash 3.0 compatible array initialization
  local actual; [[ $# -gt 0 ]] && actual=("$@")

  if [[ "${actual[*]:-}" == *"$expected"* ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}
