#!/bin/bash

# Deprecated: Please use assert_equals instead.
function assertEquals() {
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_equals "$1" "$2" "$label"
}

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

# Deprecated: Please use assert_empty instead.
function assertEmpty() {
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_empty "$1" "$label"
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

# Deprecated: Please use assert_not_empty instead.
function assertNotEmpty() {
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_not_empty "$1" "$label"
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

# Deprecated: Please use assert_not_equals instead.
function assertNotEquals() {
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_not_equals "$1" "$2" "$label"
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

# Deprecated: Please use assert_contains instead.
function assertContains() {
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_contains "$1" "$2" "$label"
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

# Deprecated: Please use assert_not_contains instead.
function assertNotContains() {
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_not_contains "$1" "$2" "$label"
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

# Deprecated: Please use assert_matches instead.
function assertMatches() {
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_matches "$1" "$2" "$label"
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

# Deprecated: Please use assert_not_matches instead.
function assertNotMatches() {
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_not_matches "$1" "$2" "$label"
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

# Deprecated: Please use assert_exit_code instead.
function assertExitCode() {
  local actual_exit_code=$?
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_exit_code "$1" "$label" "$actual_exit_code"
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

# Deprecated: Please use assert_successful_code instead.
function assertSuccessfulCode() {
  local actual_exit_code=$?
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_successful_code "$1" "$label" "$actual_exit_code"
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

# Deprecated: Please use assert_general_error instead.
function assertGeneralError() {
  local actual_exit_code=$?
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_general_error "$1" "$label" "$actual_exit_code"
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

# Deprecated: Please use assert_command_not_found instead.
function assertCommandNotFound() {
  local actual_exit_code=$?
  local label="${2:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  assert_command_not_found "{command}" "$label" "$actual_exit_code"
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

# Deprecated: Please use assert_array_contains instead.
function assertArrayContains() {
  local expected="$1"

  assert_array_contains "$expected" "${@:2}"
}

function assert_array_contains() {
  local expected="$1"
  local label="$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift

  local actual=("${@}")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  State::addAssertionsPassed
}


function assertArrayNotContains() {
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

