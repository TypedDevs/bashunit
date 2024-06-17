#!/bin/bash

function fail() {
  local message=$1
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  state::add_assertions_failed
  console_results::print_failure_message "${label}" "$message"
}

function assert_equals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  state::add_assertions_passed
}

function assert_equals_ignore_colors() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  local actual_without_colors
  actual_without_colors=$(echo -e "$actual" | sed "s/\x1B\[[0-9;]*[JKmsu]//g")

  assert_equals "$expected" "$actual_without_colors" "$label"
}

function assert_empty() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$expected" != "" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "to be empty" "but got" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_not_empty() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$expected" == "" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "to not be empty" "but got" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_not_equals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$expected" == "$actual" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  state::add_assertions_passed
}

function assert_contains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ $actual == *"$expected"* ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_contains_ignore_case() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  shopt -s nocasematch

  if ! [[ $actual =~ $expected ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to contain" "${expected}"

    shopt -u nocasematch
    return
  fi

  shopt -u nocasematch
  state::add_assertions_passed
}

function assert_not_contains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $actual == *"$expected"* ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not contain" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_matches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ $expected ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to match" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_not_matches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_exit_code() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_successful_code() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=0
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_general_error() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=1
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_command_not_found() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=127
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_starts_with() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ ^"$expected"* ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to start with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_not_starts_with() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $actual =~ ^"$expected"* ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not start with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_ends_with() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ .*"$expected"$ ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to end with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_string_not_ends_with() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ $actual =~ .*"$expected"$ ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to not end with" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_less_than() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ "$actual" -lt "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be less than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_less_or_equal_than() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ "$actual" -le "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be less or equal than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_greater_than() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ "$actual" -gt "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be greater than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_greater_or_equal_than() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if ! [[ "$actual" -ge "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${actual}" "to be greater or equal than" "${expected}"
    return
  fi

  state::add_assertions_passed
}

function assert_line_count() {
  local expected="$1"
  local input_str="$2"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [ -z "$input_str" ]; then
    local actual=0
  else
    local actual
    actual=$(echo "$input_str" | wc -l | tr -d '[:blank:]')
    if [[ actual -eq 1 ]]; then
      actual=$(grep -o '\\n' <<< "$input_str" | wc -l | tr -d '[:blank:]')
      ((actual++))
    fi
  fi

  if [[ "$expected" != "$actual" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${input_str}"\
      "to contain number of lines equal to" "${expected}"\
      "but found" "${actual}"
    return
  fi

  state::add_assertions_passed
}
