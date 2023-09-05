#!/bin/bash

export TEST=true

export assertEquals

TOTAL_TESTS=0
FAILED=false

transformTestFunctionName() {
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
  local label="${3:-$(transformTestFunctionName ${FUNCNAME[1]})}"

  if [[ "$expected" != "$actual" ]]; then
    FAILED=true
    printf "❌  ${COLOR_FAILED}Failed${COLOR_DEFAULT}: %s\\n Expected '%s'\\n but got  '%s'\\n" "$label" "$expected" "$actual"
    exit 1
  else
    ((TOTAL_TESTS++))
    printf "✔️  ${COLOR_PASSED}Passed${COLOR_DEFAULT}: %s\\n" "$label"
  fi
}

renderResult() {
  echo ""
  if [[ "$FAILED" == false ]]; then
    echo "All assertions passed. Total:" "$TOTAL_TESTS"
  fi
}

# Set a trap to call render_result when the script exits
trap renderResult EXIT
