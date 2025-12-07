#!/usr/bin/env bash

function assert_directory_exists() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  state::add_assertions_passed
}

function assert_directory_not_exists() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ -d "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to not exist but" "the directory exists"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be a directory" "but is not a directory"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_empty() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || -n "$(ls -A "$expected")" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_not_empty() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || -z "$(ls -A "$expected")" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to not be empty" "but is empty"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_readable() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || ! -r "$expected" || ! -x "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be readable" "but is not readable"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_not_readable() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" ]] || [[ -r "$expected" && -x "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be not readable" "but is readable"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_writable() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || ! -w "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be writable" "but is not writable"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_not_writable() {
  local expected="$1"
  local test_fn
  test_fn="$(bashunit::helper::find_test_function_name)"
  local label="${2:-$(bashunit::helper::normalize_test_function_name "$test_fn")}"

  if [[ ! -d "$expected" || -w "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be not writable" "but is writable"
    return
  fi

  state::add_assertions_passed
}
