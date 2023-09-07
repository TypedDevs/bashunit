#!/bin/bash

export TEST=true

export assertEquals
export assertContains
export assertNotContains

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
    echo -e "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}
    ${COLOR_FAINT}but got${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}"
  else
    ((TOTAL_PASSED++))
    echo -e "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}"
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

  case "$actual" in
    *"$expected"*)
      ((TOTAL_PASSED++))
      echo -e "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}"
      ;;
    *)
      ((TOTAL_FAILED++))
      echo -e "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}to contain${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}"
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
        echo -e "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: ${label}
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'${actual}'${COLOR_DEFAULT}
    ${COLOR_FAINT}to not contain${COLOR_DEFAULT} ${COLOR_BOLD}'${expected}'${COLOR_DEFAULT}"
        exit 1
        ;;
      *)
        ((TOTAL_PASSED++))
        echo -e "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: ${label}"
        ;;
    esac
}

renderResult() {
  echo ""
  local total_assertions=$((TOTAL_PASSED + TOTAL_FAILED))
  echo -e "${COLOR_FAINT}Total assertions found:${COLOR_DEFAULT} ${COLOR_BOLD}${total_assertions}${COLOR_DEFAULT}"

  if [ "$TOTAL_FAILED" -gt 0 ]; then
    echo -e "${COLOR_FAINT}Total assertions failed:${COLOR_DEFAULT} ${COLOR_BOLD}${COLOR_FAILED}${TOTAL_FAILED}${COLOR_DEFAULT}"
    exit 1
  else
    echo -e "${COLOR_ALL_PASSED}All assertions passed.${COLOR_DEFAULT}"
  fi
}

# Set a trap to call render_result when the script exits
trap renderResult EXIT
