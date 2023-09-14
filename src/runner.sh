#!/bin/bash

function callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local function_names
  function_names=$(declare -F | awk '{print $3}')
  local functions_to_run
  # shellcheck disable=SC2207
  functions_to_run=($(getFunctionsToRun "$prefix" "$filter" "$function_names"))

  if [ "${#functions_to_run[@]}" -gt 0 ]; then
    echo "Running $script"
    for function_name in "${functions_to_run[@]}"; do
      if [ "$PARALLEL_RUN" == true ] ; then
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
  local current_assertions_failed
  current_assertions_failed="$(getAssertionsFailed)"

  "$function_name"

  if [ "$current_assertions_failed" != "$(getAssertionsFailed)" ]; then
    addTestsFailed
    return
  fi

  addTestsPassed

  local label="${3:-$(normalizeTestFunctionName "$function_name")}"
  printSuccessfulTest "${label}"
}

function loadTestFiles() {
  if [ ${#_FILES[@]} -eq 0 ]; then
    echo "Error: At least one file path is required."
    echo "Usage: $0 <test_file.sh>"
    exit 1
  fi

  for test_file in "${_FILES[@]}"; do
    if [[ ! -f $test_file ]]; then
      continue
    fi

    #shellcheck source=/dev/null
    source "$test_file"

    callTestFunctions "$test_file" "$_FILTER"
    if [[ "$PARALLEL_RUN" = true ]]; then
      wait
    fi
  done
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

loadTestFiles

renderResult "$(getTestsPassed)" "$(getTestsFailed)" "$(getAssertionsPassed)" "$(getAssertionsFailed)"
