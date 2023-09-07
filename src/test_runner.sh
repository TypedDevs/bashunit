#!/bin/bash

# shellcheck disable=SC2155

getFunctionCode() {
  local func_name="$1"
  local script="$2"

  awk -v fn="$func_name" '
    BEGIN { in_function = 0; }
    in_function { func_code = func_code $0 "\n"; }
    $1 == "function" && $2 == fn"()" { in_function = 1; func_code = ""; }
    in_function && $1 == "}" { in_function = 0; print func_code; }
  ' "$script"
}

callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"

  local function_names=$(declare -F | awk '{print $3}')
  local functions_to_run=()

  for func_name in $function_names; do
    if [[ $func_name == ${prefix}* ]]; then
      local func_name_lower=$(echo "$func_name" | tr '[:upper:]' '[:lower:]')
      local filter_lower=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $func_name_lower == *"$filter_lower"* ]]; then
        functions_to_run+=("$func_name")
      fi
    fi
  done


if [ "${#functions_to_run[@]}" -gt 0 ]; then
  echo "Running $script"
  for func_name in "${functions_to_run[@]}"; do
    func_code=$(getFunctionCode "$func_name" "$script")

    if echo "$func_code" | grep -iq "^\s*#.*skip"; then
      echo "| Skipped:" "$(normalizeFnName "$func_name")"
    else
      "$func_name"  # Call the function
      unset "$func_name"
    fi
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
