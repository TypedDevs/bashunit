#!/bin/bash

function callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local function_names
  function_names=$(declare -F | awk '{print $3}')
  local functions_to_run=()

  for func_name in $function_names; do
    if [[ $func_name == ${prefix}* ]]; then
      local func_name_lower
      func_name_lower=$(echo "$func_name" | tr '[:upper:]' '[:lower:]')
      local filter_lower
      filter_lower=$(echo "$filter" | tr '[:upper:]' '[:lower:]')

      if [[ -z $filter || $func_name_lower == *"$filter_lower"* ]]; then
        functions_to_run+=("$func_name")
      fi
    fi
  done

  if [ "${#functions_to_run[@]}" -gt 0 ]; then
    echo "Running $script"
    for func_name in "${functions_to_run[@]}"; do
      if [ "$PARALLEL_RUN" = true ] ; then
        runTest "$func_name" &
      else
        runTest "$func_name"
      fi
      unset "$func_name"
    done
  fi
}

function runTest() {
  local func_name="$1"

  "$func_name"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    ((_TESTS_PASSED++))
    local label="${3:-$(normalizeFnName "$func_name")}"
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

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --filter)
      _FILTER="$2"
      shift
      shift
      ;;
    *)
      _FILES+=("$key")
      shift
      ;;
  esac
done

if [ ${#_FILES[@]} -eq 0 ]; then
  echo "Error: At least one file path is required."
  echo "Usage: $0 <test_script>"
  exit 1
fi

for test_script in "${_FILES[@]}"; do
  # shellcheck disable=SC1090
  source "$test_script"
  callTestFunctions "$test_script" "$_FILTER"
  if [ "$PARALLEL_RUN" = true ] ; then
      wait
  fi
done
