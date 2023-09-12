#!/bin/bash

#
# @param string Eg: "test_some_logic"
#
# @result string Eg: "Some logic"
#
function normalizeTestFunctionName() {
  local original_function_name="$1"
  local result

  # Remove "test_" prefix
  result="${original_function_name#test_}"
  # Replace underscores with spaces
  result="${result//_/ }"
  # Remove "test" prefix
  result="${result#test}"
  # Capitalize the first letter
  result="$(tr '[:lower:]' '[:upper:]' <<< "${result:0:1}")${result:1}"

  echo "$result"
}

function getFunctionsToRun() {
  local prefix=$1
  local filter=$2
  local function_names=$3

  local functions_to_run=()

  for function_name in $function_names; do
    if [[ $function_name == ${prefix}* ]]; then
      local lower_case_function_name
      lower_case_function_name=$(echo "$function_name" | tr '[:upper:]' '[:lower:]')
      local lower_case_filter
      lower_case_filter=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $lower_case_function_name == *"$lower_case_filter"* ]]; then
        if [[ "${functions_to_run[*]}" =~ ${function_name} ]]; then
          return 1
        fi
        functions_to_run+=("$function_name")
      fi
    fi
  done

  echo "${functions_to_run[@]}"
}
