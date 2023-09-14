#!/bin/bash

function assertEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  addAssertionsPassed
}

function assertNotEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "$actual" ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  addAssertionsPassed
}

function assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual == *"$expected"* ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  addAssertionsPassed
}

function assertNotContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual == *"$expected"* ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual}" "to not contain" "${expected}"
    return
  fi

  addAssertionsPassed
}

function assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ $expected ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual}" "to match" "${expected}"
    return
  fi

  addAssertionsPassed
}

function assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  addAssertionsPassed
}

function assertExitCode() {
  local actual_exit_code=$?
  local expected_exit_code="$1"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  addAssertionsPassed
}

function assertSuccessfulCode() {
  local actual_exit_code=$?
  local expected_exit_code=0
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  addAssertionsPassed
}

function assertGeneralError() {
  local actual_exit_code=$?
  local expected_exit_code=1
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  addAssertionsPassed
}


function assertCommandNotFound() {
  local actual_exit_code=$?
  local expected_exit_code=127
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  addAssertionsPassed
}

function assertArrayContains() {
  local expected="$1"
  label="$(normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  addAssertionsPassed
}

function assertArrayNotContains() {
  local expected="$1"
  label="$(normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if [[ "${actual[*]}" == *"$expected"* ]]; then
    addAssertionsFailed
    printFailedTest  "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
  fi

  addAssertionsPassed
}
