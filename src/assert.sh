#!/bin/bash

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
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${expected}" "but got" "${actual}"
    return 1
  else
    ((_ASSERTIONS_PASSED++))
    return 0
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

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

assertNotContains() {
  local expected="$1"
    local actual="$2"
    local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

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

assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_PASSED++))
    return 0
  else
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to match" "${expected}"
    return 1
  fi
}

assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_ASSERTIONS_FAILED++))
    printFailedTest  "${label}" "${actual}" "to not match" "${expected}"
    return 1
  else
    ((_ASSERTIONS_PASSED++))
    return 0
  fi
}
