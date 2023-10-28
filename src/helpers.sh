#!/bin/bash

#
# @param $1 string Eg: "test_some_logic_camelCase"
#
# @return string Eg: "Some logic camelCase"
#
function helper::normalize_test_function_name() {
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

function helper::check_duplicate_functions() {
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
    state::set_duplicated_functions_merged "$script" "$duplicates"
    return 1
  fi
}

#
# @param $1 string Eg: "prefix"
# @param $2 string Eg: "filter"
# @param $3 array Eg: "[fn1, fn2, prefix_filter_fn3, fn4, ...]"
#
# @return array Eg: "[prefix_filter_fn3, ...]" The filtered functions with prefix
#
function helper::get_functions_to_run() {
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
function helper::execute_function_if_exists() {
  local function_name=$1

  if declare -F | awk '{print $3}' | grep -Eq "^${function_name}$"; then
    "$function_name"
  fi
}

#
# @param $1 string Eg: "do_something"
#
function helper::unset_if_exists() {
  local function_name=$1

  if declare -F | awk '{print $3}' | grep -Eq "^${function_name}$"; then
    unset "$function_name"
  fi
}

function helper::read_and_store_files_recursive()
{
    local files=()
    while IFS='' read -r line; do
      files+=("$line");
    done < <(helper::find_files_recursive "$1")

    if [ ${#files[@]} -eq 0 ]; then
        files+=("$1")
    fi

    echo "${files[@]}"
}

function helper::find_files_recursive() {
  local path="$1"

  if [[ -d "$path" ]]; then
    find "$path" -type f -name '*[tT]est.sh' | sort | uniq
  else
    echo "$path"
  fi
}

helper::normalize_variable_name() {
  local input_string="$1"
  local normalized_string

  normalized_string="${input_string//[^a-zA-Z0-9_]/_}"

  if [[ ! $normalized_string =~ ^[a-zA-Z_] ]]; then
    normalized_string="_$normalized_string"
  fi

  echo "$normalized_string"
}

function helper::get_provider_data() {
  local function_name="$1"
  local script="$2"
  local data_provider_function

  if [[ ! -f "$script" ]]; then
    return
  fi

  data_provider_function=$(\
    grep -B 1 "function $function_name()" "$script" |\
    grep "# data_provider " |\
    sed -E -e 's/\ *# data_provider (.*)$/\1/g'\
  )

  if [[ -n "$data_provider_function" ]]; then
    helper::execute_function_if_exists "$data_provider_function"
  fi
}

function helper::trim() {
    local input_string="$1"
    local trimmed_string

    trimmed_string="${input_string#"${input_string%%[![:space:]]*}"}"
    trimmed_string="${trimmed_string%"${trimmed_string##*[![:space:]]}"}"

    echo "$trimmed_string"
}
