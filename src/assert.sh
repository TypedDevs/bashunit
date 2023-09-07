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
    printf "❌  ${COLOR_FAILED}Failed${COLOR_DEFAULT}: %s\\n Expected '%s'\\n but got  '%s'\\n" "$label" "$expected" "$actual"
  else
    ((TOTAL_PASSED++))
    printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: %s\\n" "$label"
  fi
}

assertContains() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(normalizeFnName ${FUNCNAME[1]})}"

  case "$actual" in
    *"$expected"*)
      ((TOTAL_PASSED++))
      printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: %s\\n" "$label"
      ;;
    *)
      ((TOTAL_FAILED++))
      printf "❌  ${COLOR_FAILED}Failed${COLOR_DEFAULT}: %s\\n Expected   '%s'\\n to contain '%s'\\n" "$label" "$actual" "$expected"
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
        printf "❌  ${COLOR_FAILED}Failed${COLOR_DEFAULT}: %s\\n Expected   '%s'\\n to not contain '%s'\\n" "$label" "$actual" "$expected"
        exit 1
        ;;
      *)
        ((TOTAL_PASSED++))
        printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: %s\\n" "$label"
        ;;
    esac
}

renderResult() {
  echo ""
  local total_assertions=$((TOTAL_PASSED + TOTAL_FAILED))
  echo "Total assertions found:" "$total_assertions"

  if [ "$TOTAL_FAILED" -gt 0 ]; then
    echo "Total assertions failed:" "$TOTAL_FAILED"
    exit 1
  else
    echo "All assertions passed."
  fi
}

# Set a trap to call render_result when the script exits
trap renderResult EXIT
