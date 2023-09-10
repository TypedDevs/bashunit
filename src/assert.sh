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
  else
    ((_ASSERTIONS_PASSED++))
    return 0
  fi
}

function assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

  case "$actual" in
    *"$expected"*)
      ((_ASSERTIONS_PASSED++))
      return 0
      ;;
    *)
      ((_ASSERTIONS_FAILED++))
      printFailedTest  "${label}" "${actual}" "to contain" "${expected}"
      return 1
      ;;
  esac
}

function assertNotContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

  case "$actual" in
    *"$expected"*)
      ((_ASSERTIONS_FAILED++))
      printFailedTest  "${label}" "${actual}" "to not contain" "${expected}"
      return 1
      ;;
    *)
      ((_ASSERTIONS_PASSED++))
      return 0
      ;;
  esac
}

function assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_PASSED++))
    return 0
  else
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to match" "${expected}"
    return 1
  fi
}

function assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFunctionName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not match" "${expected}"
    return 1
  else
    ((_ASSERTIONS_PASSED++))
    return 0
  fi
}

#
# Usage: assertExitCode 1
#
function assertExitCode() {
  local expected_exit_code="$1"
  local actual_exit_code=$?

  echo "Expected exit code: $expected_exit_code"
  echo "Actual exit code: $actual_exit_code"

  if [ $actual_exit_code -eq "$expected_exit_code" ]; then
    return 0
  else
    return 1
  fi
}
