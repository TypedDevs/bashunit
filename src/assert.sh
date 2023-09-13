#!/bin/bash

function assertEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertNotEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "$actual" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual == *"$expected"* ]]; then
      ((_ASSERTIONS_FAILED++))
      printFailedTest  "${label}" "${actual}" "to contain" "${expected}"
      return 1
    fi

    ((_ASSERTIONS_PASSED++))
    return 0
}

function assertNotContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not contain" "${expected}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to match" "${expected}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not match" "${expected}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertExitCode() {
  local actual_exit_code=$?
  local expected_exit_code="$1"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertSuccessfulCode() {
  local actual_exit_code=$?
  local expected_exit_code=0
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertGeneralError() {
  local actual_exit_code=$?
  local expected_exit_code=1
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}


function assertCommandNotFound() {
  local actual_exit_code=$?
  local expected_exit_code=127
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertArrayContains() {
  local expected="$1"
  label="$(normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")
  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual[*]}" "to contain" "${expected}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}

function assertArrayNotContains() {
  local expected="$1"
  label="$(normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")
  if [[ "${actual[*]}" == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual[*]}" "to not contain" "${expected}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}
