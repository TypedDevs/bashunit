#!/usr/bin/env bash

function assert_array_contains() {
  local expected="$1"
  local label
  label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
  shift

  local actual=("${@}")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_array_not_contains() {
  local expected="$1"
  label="$(helper::normalize_test_function_name "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if [[ "${actual[*]}" == *"$expected"* ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
  fi

  state::add_assertions_passed
}
