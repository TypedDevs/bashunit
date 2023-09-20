#!/bin/bash

function assertEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "but got" "${actual}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertEmpty() {
  local expected="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "to be empty" "but got" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertNotEmpty() {
  local expected="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "to not be empty" "but got" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertNotEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "$actual" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${expected}" "but got" "${actual}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to contain" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertNotContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to not contain" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ $expected ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to match" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual}" "to not match" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertExitCode() {
  local actual_exit_code=$?
  local expected_exit_code="$1"
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertSuccessfulCode() {
  local actual_exit_code=$?
  local expected_exit_code=0
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertGeneralError() {
  local actual_exit_code=$?
  local expected_exit_code=1
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}


function assertCommandNotFound() {
  local actual_exit_code=$?
  local expected_exit_code=127
  local label="${3:-$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code -ne "$expected_exit_code" ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertArrayContains() {
  local expected="$1"
  label="$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual[*]}" "to contain" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}

function assertArrayNotContains() {
  local expected="$1"
  label="$(Helper::normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if [[ "${actual[*]}" == *"$expected"* ]]; then
    State::addAssertionsFailed
    Console::printFailedTest "${label}" "${actual[*]}" "to not contain" "${expected}"
    return 1
  fi

  State::addAssertionsPassed

  return 0
}
