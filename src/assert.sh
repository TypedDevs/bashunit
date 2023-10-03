#!/bin/bash

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

function assert_file_exists() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -f "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  state::add_assertions_passed
}

function assert_file_not_exists() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ -f "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to not exist but" "the file exists"
    return
  fi

  state::add_assertions_passed
}

function assert_is_file() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -f "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be a file" "but is not a file"
    return
  fi

  state::add_assertions_passed
}

function assert_is_file_empty() {
  local expected="$1"
  local label="${3:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ -s "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  state::add_assertions_passed
}

function assert_directory_exists() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  state::add_assertions_passed
}

function assert_directory_not_exists() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ -d "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to not exist but" "the directory exists"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be a directory" "but is not a directory"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_empty() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || -n "$(ls -A "$expected")" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_not_empty() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || -z "$(ls -A "$expected")" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to not be empty" "but is empty"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_readable() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || ! -r "$expected" || ! -x "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be readable" "but is not readable"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_not_readable() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" ]] || [[ -r "$expected" && -x "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be not readable" "but is readable"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_writable() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || ! -w "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be writable" "but is not writable"
    return
  fi

  state::add_assertions_passed
}

function assert_is_directory_not_writable() {
  local expected="$1"
  local label="${2:-$(helper::normalize_test_function_name "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || -w "$expected" ]]; then
    state::add_assertions_failed
    console_results::print_failed_test "${label}" "${expected}" "to be not writable" "but is writable"
    return
  fi

  state::add_assertions_passed
}
