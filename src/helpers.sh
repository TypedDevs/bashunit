#!/bin/bash

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @result string Eg: "Some logic camelCase"
#
function Helper::normalizeTestFunctionName() {
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

#
# @param $1 string Eg: "prefix"
# @param $2 string Eg: "filter"
# @param $3 array Eg: "[fn1, fn2, prefix_filter_fn3, fn4, ...]"
#
# @result array Eg: "[prefix_filter_fn3, ...]" The filtered functions with prefix
#
function Helper::getFunctionsToRun() {
  local prefix=$1
  local filter=$2
  local function_names=$3

  local functions_to_run=()

  for function_name in $function_names; do
    if [[ $function_name != ${prefix}* ]]; then
      continue
    fi

    local lower_case_function_name
    lower_case_function_name=$(echo "$function_name" | tr '[:upper:]' '[:lower:]')
    local lower_case_filter
    lower_case_filter=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

    if [[ -n $filter && $lower_case_function_name != *"$lower_case_filter"* ]]; then
      continue
    fi

    if [[ "${functions_to_run[*]}" =~ ${function_name} ]]; then
      return 1
    fi

    functions_to_run+=("$function_name")
  done

  echo "${functions_to_run[@]}"
}

#
# @param $1 string Eg: "do_something"
#
function Helper::executeFunctionIfExists() {
  local function_name=$1

  if declare -F | awk '{print $3}' | grep -Eq "^${function_name}$"; then
    "$function_name"
  fi
}

#
# @param $1 string Eg: "do_something"
#
function Helper::unsetIfExists() {
  local function_name=$1

  if declare -F | awk '{print $3}' | grep -Eq "^${function_name}$"; then
    unset "$function_name"
    return 0
  fi

  return 1
}
