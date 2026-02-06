#!/usr/bin/env bash

function assert_date_equals() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if [[ "$actual" -ne "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be equal to" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_before() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -lt "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be before" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_after() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"

  if ! [[ "$actual" -gt "$expected" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be after" "${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_within_range() {
  bashunit::assert::should_skip && return 0

  local from="$1"
  local to="$2"
  local actual="$3"

  if [[ "$actual" -lt "$from" ]] || [[ "$actual" -gt "$to" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be between" "${from} and ${to}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_date_within_delta() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local actual="$2"
  local delta="$3"

  local diff=$(( actual - expected ))
  if [[ "$diff" -lt 0 ]]; then
    diff=$(( -diff ))
  fi

  if [[ "$diff" -gt "$delta" ]]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${actual}" "to be within" "${delta} seconds of ${expected}"
    return
  fi

  bashunit::state::add_assertions_passed
}
