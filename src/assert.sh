#!/bin/bash

export TEST=true

export assertEquals
export assertContains
export assertNotContains
export assertMatches

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
  local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

  if [[ "$expected" != "$actual" ]]; then
    ((_TOTAL_ASSERTIONS_FAILED++))
    printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}
    ${COLOR_FAINT}but got${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}\n"
  else
    ((_TOTAL_ASSERTIONS_PASSED++))
    printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

  case "$actual" in
    *"$expected"*)
      ((_TOTAL_ASSERTIONS_PASSED++))
      printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
      ;;
    *)
      ((_TOTAL_ASSERTIONS_FAILED++))
      printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}to contain${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n"
      exit 1
      ;;
  esac
}

assertNotContains() {
  local expected="$1"
    local actual="$2"
    local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

    case "$actual" in
      *"$expected"*)
        ((_TOTAL_ASSERTIONS_FAILED++))
        printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}to not contain${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n"
        exit 1
        ;;
      *)
        ((_TOTAL_ASSERTIONS_PASSED++))
        printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
        ;;
    esac
}

assertMatches() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

  if [[ $actual =~ $expected ]]; then
    ((_TOTAL_ASSERTIONS_PASSED++))
    printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
  else
    ((_TOTAL_ASSERTIONS_FAILED++))
          printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}to match${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n"
    exit 1
  fi
}
