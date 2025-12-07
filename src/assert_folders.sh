#!/usr/bin/env bash

function assert_directory_exists() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_directory_not_exists() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ -d "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to not exist but" "the directory exists"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be a directory" "but is not a directory"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || -n "$(ls -A "$expected")" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory_not_empty() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || -z "$(ls -A "$expected")" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to not be empty" "but is empty"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory_readable() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || ! -r "$expected" || ! -x "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be readable" "but is not readable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory_not_readable() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" ]] || [[ -r "$expected" && -x "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be not readable" "but is readable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory_writable() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || ! -w "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be writable" "but is not writable"
    return
  fi

  bashunit::state::add_assertions_passed
}

function assert_is_directory_not_writable() {
  bashunit::assert::should_skip && return 0

  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || -w "$expected" ]]; then
    bashunit::assert::mark_failed
    bashunit::console_results::print_failed_test "${label}" "${expected}" "to be not writable" "but is writable"
    return
  fi

  bashunit::state::add_assertions_passed
}
