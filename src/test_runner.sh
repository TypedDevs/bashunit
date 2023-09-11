#!/bin/bash

function callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local function_names
  function_names=$(declare -F | awk '{print $3}')
  local functions_to_run=()

  for function_name in $function_names; do
    if [[ $function_name == ${prefix}* ]]; then
      local lower_case_function_name
      lower_case_function_name=$(echo "$function_name" | tr '[:upper:]' '[:lower:]')
      local lower_case_filter
      lower_case_filter=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $lower_case_function_name == *"$lower_case_filter"* ]]; then
        functions_to_run+=("$function_name")
      fi
    fi
  done

  if [ "${#functions_to_run[@]}" -gt 0 ]; then
    echo "Running $script"
    for function_name in "${functions_to_run[@]}"; do
      if [ "$PARALLEL_RUN" = true ] ; then
        runTest "$function_name" &
      else
        runTest "$function_name"
      fi
      unset "$function_name"
    done
  fi
}

function runTest() {
  local function_name="$1"

  "$function_name"
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    ((_TESTS_PASSED++))
    local label="${3:-$(normalizeTestFunctionName "$function_name")}"
    printSuccessfulTest "${label}"
  else
    ((_TESTS_FAILED++))
  fi
}

###############
#### MAIN #####
###############

_FILES=()
_FILTER=""

while [ $# -gt 0 ]; do
  argument="$1"
  case $argument in
    --filter)
      _FILTER="$2"
      shift
      shift
      ;;
    *)
      _FILES+=("$argument")
      shift
      ;;
  esac
done

if [ ${#_FILES[@]} -eq 0 ]; then
  echo "Error: At least one file path is required."
  echo "Usage: $0 <test_file.sh>"
  exit 1
fi

for test_file in "${_FILES[@]}"; do
  # shellcheck disable=SC1090
  source "$test_file"
  callTestFunctions "$test_file" "$_FILTER"
  if [ "$PARALLEL_RUN" = true ] ; then
    wait
  fi
done
