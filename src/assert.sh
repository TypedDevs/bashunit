#!/bin/bash

function normalizeFunctionName() {
  local original_function_name="$1"
  local result

  # Remove "test_" prefix
  result="${original_function_name#test_}"
  # Replace underscores with spaces
  result="${result//_/ }"
  # Remove "test" prefix
  result="${result#test}"
  # Capitalize the first letter
  result="$(tr '[:lower:]' '[:upper:]' <<< "${result:0:1}")${result:1}"

  echo "$result"
}

function assertEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
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
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

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
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

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
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

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
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

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
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

  if [ $actual_exit_code -ne "$expected_exit_code" ]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual_exit_code}" "to not match" "${expected_exit_code}"
    return 1
  fi

  ((_ASSERTIONS_PASSED++))
  return 0
}
