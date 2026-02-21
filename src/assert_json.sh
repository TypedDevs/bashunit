#!/usr/bin/env bash

function bashunit::assert_json::require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    bashunit::skip "jq is required for JSON assertions"
    return 1
  fi
  return 0
}

function assert_json_key_exists() {
  bashunit::assert::should_skip && return 0
  bashunit::assert_json::require_jq || return 0

  local key="$1"
  local json="$2"

  local result
  if ! result=$(printf '%s' "$json" | jq -e "$key" 2>/dev/null) || [ "$result" = "null" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${json}" "to have key" "${key}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_json_contains() {
  bashunit::assert::should_skip && return 0
  bashunit::assert_json::require_jq || return 0

  local key="$1"
  local expected="$2"
  local json="$3"

  local result
  if ! result=$(printf '%s' "$json" | jq -e -r "$key" 2>/dev/null) || [ "$result" = "null" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${json}" "to have key" "${key}"
    return
  fi

  if [ "$result" != "$expected" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "but got " "${result}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_json_equals() {
  bashunit::assert::should_skip && return 0
  bashunit::assert_json::require_jq || return 0

  local expected="$1"
  local actual="$2"

  local expected_sorted
  expected_sorted=$(printf '%s' "$expected" | jq -S '.' 2>/dev/null)
  local actual_sorted
  actual_sorted=$(printf '%s' "$actual" | jq -S '.' 2>/dev/null)

  if [ "$expected_sorted" != "$actual_sorted" ]; then
    local test_fn
    test_fn="$(bashunit::helper::find_test_function_name)"
    local label
    label="$(bashunit::helper::normalize_test_function_name "$test_fn")"
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}
