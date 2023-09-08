#!/bin/bash

export TEST=true

export assertEquals
export assertContains
export assertNotContains
export assertMatches
export assertNotMatches

_TOTAL_ASSERTIONS_FAILED=0
_TOTAL_ASSERTIONS_PASSED=0

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
    printf "\
${COLOR_FAILED}%s${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}\n" \
    "✗ Failed" "Expected" "but got"
  else
    ((_TOTAL_ASSERTIONS_PASSED++))
    printf "${COLOR_PASSED}%s${COLOR_DEFAULT}: ${label}\n" "✓ Passed"
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  case "$actual" in
    *"$expected"*)
      ((_TOTAL_ASSERTIONS_PASSED++))
      printf "${COLOR_PASSED}%s${COLOR_DEFAULT}: ${label}\n" "✓ Passed"
      ;;
    *)
      ((_TOTAL_ASSERTIONS_FAILED++))
      printf "\
${COLOR_FAILED}%s${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n" \
    "✗ Failed" "Expected" "to contain"
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
        printf "\
${COLOR_FAILED}%s${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n" \
        "✗ Failed" "Expected" "to not contain"
        exit 1
        ;;
      *)
        ((_TOTAL_ASSERTIONS_PASSED++))
        printf "${COLOR_PASSED}%s${COLOR_DEFAULT}: ${label}\n" "✓ Passed"
        ;;
    esac
}

assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_TOTAL_ASSERTIONS_PASSED++))
    printf "${COLOR_PASSED}%s${COLOR_DEFAULT}: ${label}\n" "✓ Passed"
  else
    ((_TOTAL_ASSERTIONS_FAILED++))
    printf "\
${COLOR_FAILED}%s${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n" \
    "✗ Failed" "Expected" "to match"
    exit 1
  fi
}

assertNotMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName "${FUNCNAME[1]}")}"

  if [[ $actual =~ $expected ]]; then
    ((_TOTAL_ASSERTIONS_FAILED++))
    printf "\
${COLOR_FAILED}%s${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n" \
    "✗ Failed" "Expected" "to not match"
    exit 1
  else
    ((_TOTAL_ASSERTIONS_PASSED++))
    printf "${COLOR_PASSED}%s${COLOR_DEFAULT}: ${label}\n" "✓ Passed"
  fi
}
