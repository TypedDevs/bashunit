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
    bashunit::assert::fail_with "" "${json}" "to have key" "${key}"
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
    bashunit::assert::fail_with "" "${json}" "to have key" "${key}"
    return
  fi

  if [ "$result" != "$expected" ]; then
    bashunit::assert::fail_with "" "${expected}" "but got " "${result}"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_json_equals() {
  bashunit::assert::should_skip && return 0
  bashunit::assert_json::require_jq || return 0

  local expected="$1"
  local actual="$2"

  # jq -S prints nothing (not an error message) on invalid JSON, so its exit
  # code -- not just its output -- has to gate the comparison: two inputs that
  # both fail to parse would otherwise both sort to "" and compare equal,
  # reporting unparseable input as matching JSON instead of failing.
  local expected_sorted actual_valid=true expected_valid=true
  expected_sorted=$(printf '%s' "$expected" | jq -S '.' 2>/dev/null) || expected_valid=false
  local actual_sorted
  actual_sorted=$(printf '%s' "$actual" | jq -S '.' 2>/dev/null) || actual_valid=false

  if [ "$expected_valid" = false ] || [ "$actual_valid" = false ] ||
    [ "$expected_sorted" != "$actual_sorted" ]; then
    bashunit::assert::fail_with "" "${expected}" "but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}
