#!/bin/bash

export TEST=true

export assert

TOTAL_TESTS=0
FAILED=false

transform_test_function_name() {
  local originalFnName="$1"
  local result

  # Remove "test_" prefix
  result="${originalFnName#test_}"
  # Replace underscores with spaces
  result="${result//_/ }"
  # Capitalize the first letter
  result="$(tr '[:lower:]' '[:upper:]' <<< "${result:0:1}")${result:1}"

  echo "$result"
}

assert() {
  local expected="$1"
  local actual="$2"
  local label="${3:-$(transform_test_function_name ${FUNCNAME[1]})}"

  if [[ "$expected" != "$actual" ]]; then
    FAILED=true
    printf "❌  %s failed:\\n Expected '%s'\\n but got  '%s'\\n" "$label" "$expected" "$actual"
    exit 1
  else
    ((TOTAL_TESTS++))
    printf "✔️  Passed: %s\\n" "$label"
  fi
}

render_result() {
  echo ""
  if [[ "$FAILED" == false ]]; then
    echo "All assertions passed. Total:" "$TOTAL_TESTS"
  fi
}

# Set a trap to call render_result when the script exits
trap render_result EXIT
