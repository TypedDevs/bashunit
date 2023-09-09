#!/bin/bash

export TEST=true

export assertEquals
export assertContains
export assertNotContains
export assertMatches
export assertNotMatches


normalizeFnName() {
  local originalFnName="$1"
  local result

  # Remove "test_" prefix
  result="${originalFnName#test_}"
  # Replace underscores with spaces
  result="${result//_/ }"
  # Remove "test" prefix
  result="${result#test}"
  # Capitalize the first letter
  result="$(tr '[:lower:]' '[:upper:]' <<< "${result:0:1}")${result:1}"

  echo "$result"
}

assertEquals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ "$expected" != "$actual" ]]; then
    ((_TOTAL_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    exit 1
  else
    ((_TOTAL_ASSERTIONS_PASSED++))
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  case "$actual" in
    *"$expected"*)
      ((_TOTAL_ASSERTIONS_PASSED++))
      ;;
    *)
      ((_TOTAL_ASSERTIONS_FAILED++))
      printFailedTest  "${label}" "${actual}" "to contain" "${expected}"
      exit 1
      ;;
  esac
}

assertNotContains() {
  local expected="$1"
    local actual="$2"
    local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

    case "$actual" in
      *"$expected"*)
        ((_TOTAL_ASSERTIONS_FAILED++))
        printFailedTest  "${label}" "${actual}" "to not contain" "${expected}"
        exit 1
        ;;
      *)
        ((_TOTAL_ASSERTIONS_PASSED++))
        ;;
    esac
}

assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_TOTAL_ASSERTIONS_PASSED++))
  else
    ((_TOTAL_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to match" "${expected}"
    exit 1
  fi
}

assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_TOTAL_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not match" "${expected}"
    exit 1
  else
    ((_TOTAL_ASSERTIONS_PASSED++))
  fi
}
