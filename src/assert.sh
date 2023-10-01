#!/bin/bash

function assert_equals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  State::addAssertionsPassed
}

function assert_empty() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "to be empty" "but got" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_not_empty() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "to not be empty" "but got" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_not_equals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "$actual" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  State::addAssertionsPassed
}

function assert_contains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_not_contains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to not contain" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_matches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ $expected ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to match" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_not_matches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_exit_code() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assert_successful_code() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=0
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$actual_exit_code" -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assert_general_error() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=1
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assert_command_not_found() {
  local actual_exit_code=${3-"$?"}
  local expected_exit_code=127
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assert_array_contains() {
  local expected="$1"
  local label
  label="$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift

  local actual=("${@}")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_array_not_contains() {
  local expected="$1"
  label="$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if [[ "${actual[*]}" == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
  fi

  State::addAssertionsPassed
}

function assert_file_exists() {
  local expected="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -f "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  State::addAssertionsPassed
}

function assert_file_not_exists() {
  local expected="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ -f "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to not exist but" "the file exists"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_file() {
  local expected="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -f "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be a file" "but is not a file"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_file_empty() {
  local expected="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ -s "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  State::addAssertionsPassed
}

function assert_directory_exists() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to exist but" "do not exist"
    return
  fi

  State::addAssertionsPassed
}

function assert_directory_not_exists() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ -d "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to not exist but" "the directory exists"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be a directory" "but is not a directory"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory_empty() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || -n "$(ls -A "$expected")" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be empty" "but is not empty"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory_not_empty() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || -z "$(ls -A "$expected")" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to not be empty" "but is empty"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory_readable() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || ! -r "$expected" || ! -x "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be readable" "but is not readable"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory_not_readable() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" ]] || [[ -r "$expected" && -x "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be not readable" "but is readable"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory_writable() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || ! -w "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be writable" "but is not writable"
    return
  fi

  State::addAssertionsPassed
}

function assert_is_directory_not_writable() {
  local expected="$1"
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ ! -d "$expected" || -w "$expected" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "to be not writable" "but is writable"
    return
  fi

  State::addAssertionsPassed
}
