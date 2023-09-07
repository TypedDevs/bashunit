#!/bin/bash

# shellcheck disable=SC2155
# shellcheck disable=SC2034
callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"

  # Use declare -F to list all function names
  local function_names=$(declare -F | awk '{print $3}')

  for func_name in $function_names; do
    if [[ $func_name == ${prefix}* ]]; then
      local func_name_lower=$(echo "$func_name" | tr '[:upper:]' '[:lower:]')
      local filter_lower=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $func_name_lower == *"$filter_lower"* ]]; then
        "$func_name" # Call the function
        unset "$func_name"
      fi
    fi
  done
}

FILES=()
FILTER=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --filter)
      FILTER="$2"
      shift
      shift
      ;;
    *)
      FILES+=("$key") # Add the argument to the list of files
      shift
      ;;
  esac
done

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: At least one file path is required."
    echo "Usage: $0 <test_script>"
    exit 1
fi

# Loop through the test scripts and call test functions
for test_script in "${FILES[@]}"; do
  echo "Running $test_script"
  # shellcheck disable=SC1090
  source "$test_script"
  callTestFunctions "$test_script" "$FILTER"
done
