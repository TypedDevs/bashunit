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
  local current_assertions_failed="$_ASSERTIONS_FAILED"

  runSetUp
  "$function_name"
  runTearDown

  if [ "$current_assertions_failed" == "$_ASSERTIONS_FAILED" ]; then
    ((_TESTS_PASSED++))
    local label="${3:-$(normalizeTestFunctionName "$function_name")}"
    printSuccessfulTest "${label}"
  else
    ((_TESTS_FAILED++))
  fi
}

function runSetUp() {
  executeFunctionIfExists 'setUp'
}

function runSetUpBeforeScript() {
  executeFunctionIfExists 'setUpBeforeScript'
}

function runTearDown() {
  executeFunctionIfExists 'tearDown'
}

function runTearDownAfterScript() {
  executeFunctionIfExists 'tearDownAfterScript'
}

function cleanSetUpAndTearDownAfterTest() {
  unsetIfExists 'setUp'
  unsetIfExists 'tearDown'
}

function cleanSetUpAndTearDownAfterScript() {
  unsetIfExists 'setUpBeforeScript'
  unsetIfExists 'tearDownAfterScript'
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



function loadTestFiles() {
  if [ ${#_FILES[@]} -eq 0 ]; then
    echo "Error: At least one file path is required."
    echo "Usage: $0 <test_file.sh>"
    exit 1
  fi

  for test_file in "${_FILES[@]}"; do
    if [[ ! -f $test_file ]];
    then
      continue
    fi
    # shellcheck disable=SC1090
    source "$test_file"
    runSetUpBeforeScript
    callTestFunctions "$test_file" "$_FILTER"
    if [ "$PARALLEL_RUN" = true ] ; then
      wait
    fi
    runTearDownAfterScript

    cleanSetUpAndTearDownAfterScript
  done
}

loadTestFiles

