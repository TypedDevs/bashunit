#!/bin/bash

# shellcheck disable=SC2155
# shellcheck disable=SC2034
callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  local ran_functions=false

  # Use declare -F to list all function names
  local function_names=$(declare -F | awk '{print $3}')

  for func_name in $function_names; do
    if [[ $func_name == ${prefix}* ]]; then
      local func_name_lower=$(echo "$func_name" | tr '[:upper:]' '[:lower:]')
      local filter_lower=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $func_name_lower == *"$filter_lower"* ]]; then
        functions_to_run+=("$func_name")  # Add eligible function to the array
        ran_functions=true
      fi
    fi
  done

  if [ "$ran_functions" == true ]; then
    echo "Running $script"
    for func_name in "${functions_to_run[@]}"; do
      "$func_name"  # Call the function
      unset "$func_name"
    done
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
done
