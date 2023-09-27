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

function assertNotContains() {
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

function assertMatches() {
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

function assertNotMatches() {
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

function assertExitCode() {
  local actual_exit_code=$?
  local expected_exit_code="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assertSuccessfulCode() {
  local actual_exit_code=$?
  local expected_exit_code=0
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assertGeneralError() {
  local actual_exit_code=$?
  local expected_exit_code=1
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}


function assertCommandNotFound() {
  local actual_exit_code=$?
  local expected_exit_code=127
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  State::addAssertionsPassed
}

function assertArrayContains() {
  local expected="$1"
  label="$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

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

