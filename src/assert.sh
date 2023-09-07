#!/bin/bash

export TEST=true

export assertEquals
export assertContains
export assertNotContains
export renderResult

TOTAL_FAILED=0
TOTAL_PASSED=0

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
    ((TOTAL_FAILED++))
    printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}
    ${COLOR_FAINT}but got${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}\n"
  else
    ((TOTAL_PASSED++))
    printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

  case "$actual" in
    *"$expected"*)
      ((TOTAL_PASSED++))
      printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
      ;;
    *)
      ((TOTAL_FAILED++))
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
        ((TOTAL_FAILED++))
        printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}to not contain${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}\n"
        exit 1
        ;;
      *)
        ((TOTAL_PASSED++))
        printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}\n"
        ;;
    esac
}

function renderResult() {
  local totalPassed=$1
  local totalFailed=$2
  local totalTests=$3

  echo ""
  local totalAssertions=$((totalPassed + totalFailed))
  printf "\
${COLOR_FAINT}Total tests:${COLOR_DEFAULT} ${COLOR_BOLD}${totalTests}${COLOR_DEFAULT}
${COLOR_FAINT}Total assertions:${COLOR_DEFAULT} ${COLOR_BOLD}${totalAssertions}${COLOR_DEFAULT}\n"

  if [ "$TOTAL_FAILED" -gt 0 ]; then
    printf "${COLOR_FAINT}Total assertions failed:${COLOR_DEFAULT} ${COLOR_BOLD}${COLOR_FAILED}${TOTAL_FAILED}${COLOR_DEFAULT}\n"
    exit 1
  else
    printf "${COLOR_ALL_PASSED}All assertions passed.${COLOR_DEFAULT}\n"
  fi
}

# Set a trap to call render_result when the script exits
trap 'renderResult $TOTAL_PASSED $TOTAL_FAILED $TOTAL_TESTS' EXIT
