#!/bin/bash

function Runner::callTestFunctions() {
  local script="$1"
  local filter="$2"
  local prefix="test"
  # Use declare -F to list all function names
  local function_names
  function_names=$(declare -F | awk '{print $3}')
  local functions_to_run
  # shellcheck disable=SC2207
  functions_to_run=($(Helper::getFunctionsToRun "$prefix" "$filter" "$function_names"))

  if [[ "${#functions_to_run[@]}" -gt 0 ]]; then
    echo "Running $script"
    for function_name in "${functions_to_run[@]}"; do
      Runner::runTest "$function_name"

      unset "$function_name"
    done
  fi
}

function Runner::runTest() {
  local function_name="$1"
  local current_assertions_failed
  current_assertions_failed="$(State::getAssertionsFailed)"

  Runner::runSetUp
  "$function_name"
  Runner::runTearDown

  if [[ "$current_assertions_failed" != "$(State::getAssertionsFailed)" ]]; then
    State::addTestsFailed
    return
  fi

  local label="${3:-$(Helper::normalizeTestFunctionName "$function_name")}"
  Console::printSuccessfulTest "${label}"
  State::addTestsPassed
}

function Runner::loadTestFiles() {
  if [[ ${#_FILES[@]} -eq 0 ]]; then
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

    Runner::runSetUpBeforeScript
    Runner::callTestFunctions "$test_file" "$_FILTER"
    Runner::runTearDownAfterScript
    Runner::cleanSetUpAndTearDownAfterScript
  done
}

function Runner::runSetUp() {
  Helper::executeFunctionIfExists 'setUp'
}

function Runner::runSetUpBeforeScript() {
  Helper::executeFunctionIfExists 'setUpBeforeScript'
}

function Runner::runTearDown() {
  Helper::executeFunctionIfExists 'tearDown'
}

function Runner::runTearDownAfterScript() {
  Helper::executeFunctionIfExists 'tearDownAfterScript'
}

function Runner::cleanSetUpAndTearDownAfterTest() {
  Helper::unsetIfExists 'setUp'
  Helper::unsetIfExists 'tearDown'
}

function Runner::cleanSetUpAndTearDownAfterScript() {
  Helper::unsetIfExists 'setUpBeforeScript'
  Helper::unsetIfExists 'tearDownAfterScript'
}

###############
#### MAIN #####
###############

_FILES=()
_FILTER=""

while [[ $# -gt 0 ]]; do
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

Runner::loadTestFiles

trap 'Console::renderResult '\
'"$(State::getTestsPassed)" '\
'"$(State::getTestsFailed)" '\
'"$(State::getAssertionsPassed)" '\
'"$(State::getAssertionsFailed)"' EXIT
