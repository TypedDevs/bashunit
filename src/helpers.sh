#!/bin/bash

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
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

function Helper::checkDuplicateFunctions() {
  local script="$1"

  local filtered_lines
  filtered_lines=$(grep -E '^\s*(function)?\s*test[a-zA-Z_][a-zA-Z_0-9]*\s*\(\)?\s*{' "$script")

  local function_names
  function_names=$(echo "$filtered_lines" | awk '{gsub(/\(|\)/, ""); print $2}')

  local sorted_names
  sorted_names=$(echo "$function_names" | sort)

  local duplicates
  duplicates=$(echo "$sorted_names" | uniq -d)
  if [ -n "$duplicates" ]; then
    State::setDuplicatedTestFunctionsFound
    return 1
  fi

  return 0
}

#
# @param $1 string Eg: "prefix"
# @param $2 string Eg: "filter"
# @param $3 array Eg: "[fn1, fn2, prefix_filter_fn3, fn4, ...]"
#
# @return array Eg: "[prefix_filter_fn3, ...]" The filtered functions with prefix
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
  fi
}
