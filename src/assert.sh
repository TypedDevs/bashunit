#!/bin/bash

function assertEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertEmpty() {
  local expected="$1"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "to be empty" "but got" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertNotEmpty() {
  local expected="$1"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "to not be empty" "but got" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertNotEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" == "$actual" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to contain" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertNotContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not contain" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if ! [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to match" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not match" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertExitCode() {
  local actual_exit_code=$?
  local expected_exit_code="$1"
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be" "${expected_exit_code}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertSuccessfulCode() {
  local actual_exit_code=$?
  local expected_exit_code=0
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual_exit_code != "$expected_exit_code" ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertGeneralError() {
  local actual_exit_code=$?
  local expected_exit_code=1
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}


function assertCommandNotFound() {
  local actual_exit_code=$?
  local expected_exit_code=127
  local label="${3:-$(normalizeTestFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to be exactly" "${expected_exit_code}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertArrayContains() {
  local expected="$1"
  label="$(normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if ! [[ "${actual[*]}" == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual[*]}" "to contain" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}

function assertArrayNotContains() {
  local expected="$1"
  label="$(normalizeTestFunctionName "${FUNCNAME[1]}")"
  shift
  local actual=("$@")

  if [[ "${actual[*]}" == *"$expected"* ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual[*]}" "to not contain" "${expected}"
    return
  fi

  ((_ASSERTIONS_PASSED++))
}
