#!/usr/bin/env bash

function assert_array_contains() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  shift

  local actual=("${@}")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    bashunit::state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_array_not_contains() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label
  label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
  shift
  local actual=("$@")

  if [[ "${actual[*]}" == *"$expected"* ]]; then
    bashunit::state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}
