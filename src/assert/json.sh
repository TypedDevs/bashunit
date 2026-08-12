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

function assert_json_key_not_exists() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 2 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 2 "key, json" "$#"
    return 2
  fi
  bashunit::assert_json::require_jq || return 0

  local key="$1"
  local json="$2"

  if ! printf '%s' "$json" | jq -e 'true' >/dev/null 2>&1; then
    bashunit::assert::fail_with "" "${json}" "to be valid JSON" ""
    return
  fi

  local exists
  if ! exists=$(printf '%s' "$json" | jq -r \
    "(path($key)) as \$path | if \$path == [] then true else any(paths; . == \$path) end" \
    2>/dev/null); then
    bashunit::assert::fail_with "" "${json}" "to use a valid key path" "${key}"
    return
  fi

  if [ "$exists" = true ]; then
    bashunit::assert::fail_with "" "${json}" "to not have key" "${key}"
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

function assert_json_length() {
  bashunit::assert::should_skip && return 0
  if [ "$#" -lt 3 ]; then
    bashunit::assert::usage_error "${FUNCNAME[0]}" 3 "expected, key, json" "$#"
    return 2
  fi

  local expected="$1"
  local key="$2"
  local json="$3"

  case "$expected" in
  '' | *[!0-9]*)
    bashunit::assert::usage_error_detail "${FUNCNAME[0]}" \
      "expects a non-negative integer length, got '$expected'"
    return 2
    ;;
  esac

  bashunit::assert_json::require_jq || return 0

  if ! printf '%s' "$json" | jq -e 'true' >/dev/null 2>&1; then
    bashunit::assert::fail_with "" "${json}" "to be valid JSON" ""
    return
  fi

  local exists
  if ! exists=$(printf '%s' "$json" | jq -r \
    "(path($key)) as \$path | if \$path == [] then true else any(paths; . == \$path) end" \
    2>/dev/null); then
    bashunit::assert::fail_with "" "${json}" "to use a valid key path" "${key}"
    return
  fi
  if [ "$exists" != true ]; then
    bashunit::assert::fail_with "" "${json}" "to have path" "${key}"
    return
  fi

  local actual
  local length_filter
  length_filter="$key | if type == \"array\" or type == \"object\" or type == \"string\""
  length_filter="$length_filter then length else error(\"unsupported type\") end"
  if ! actual=$(printf '%s' "$json" | jq -r "$length_filter" 2>/dev/null); then
    bashunit::assert::fail_with "" "${json}" "to have a measurable length at path" "${key}"
    return
  fi

  if [ "$actual" != "$expected" ]; then
    bashunit::assert::fail_with "" "${expected}" "but got " "${actual}"
    return
  fi

  bashunit::state::add_assertions_passed
}
