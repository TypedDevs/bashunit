#!/bin/bash

export _TOTAL_TESTS

_TOTAL_TESTS=0

# shellcheck disable=SC2155
# shellcheck disable=SC2034
callTestFunctions() {
  _TIME_START=$(date +%s%N);
  local script="$1"
  local filter="$2"
  local prefix="test"

  # Use declare -F to list all function names
  local function_names=$(declare -F | awk '{print $3}')

  local functions_to_run=()  # Initialize an array to store eligible function names

  for func_name in $function_names; do
    if [[ $func_name == ${prefix}* ]]; then
      local func_name_lower=$(echo "$func_name" | tr '[:upper:]' '[:lower:]')
      local filter_lower=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $func_name_lower == *"$filter_lower"* ]]; then
        functions_to_run+=("$func_name")  # Add eligible function to the array
      fi
    fi
  done

  if [ "${#functions_to_run[@]}" -gt 0 ]; then
    echo "Running $script"
    for func_name in "${functions_to_run[@]}"; do
      ((_TOTAL_TESTS++))
      if [ "$PARALLEL_RUN" = true ] ; then
        runTest "$func_name" & # Call the function
      else
        runTest "$func_name"
      fi
      unset "$func_name"
    done
  fi
}

runTest() {
  local func_name="$1"

  "$func_name"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    local label="${3:-$(normalizeFnName "$func_name")}"
    printSuccessfulTest "${label}"
  fi
}


###############
#### MAIN #####
###############

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

# Print the "Running $script" message before entering the loop
for test_script in "${FILES[@]}"; do
  # shellcheck disable=SC1090
  source "$test_script"
  callTestFunctions "$test_script" "$FILTER"
  if [ "$PARALLEL_RUN" = true ] ; then
      wait # Wait to finish the run of all the test from the same file
  fi
done
