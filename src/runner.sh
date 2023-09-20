#!/bin/bash

# shellcheck disable=SC2317

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
    Helper::checkDuplicateFunctions "$script"

    for function_name in "${functions_to_run[@]}"; do
      Runner::runTest "$function_name"

      unset "$function_name"
    done
  fi
}

function Runner::runTest() {
  local function_name="$1"
  local current_assertions_failed
  local test_result_code=0
  current_assertions_failed="$(State::getAssertionsFailed)"

  Runner::runSetUp
  "$function_name" || test_result_code=$?
  Runner::runTearDown

  if [[ "$current_assertions_failed" != "$(State::getAssertionsFailed)" ]]; then
    State::addTestsFailed
    return
  fi

  if [[ $test_result_code -ne 0 ]]; then
    State::addTestsFailed
    Console::printErrorTest "$function_name" "$test_result_code"
    return
  fi

  local label="${3:-$(Helper::normalizeTestFunctionName "$function_name")}"
  Console::printSuccessfulTest "${label}"
  State::addTestsPassed
}

function Runner::loadTestFiles() {
  local filter=$1
  local files=("${@:2}") # Store all arguments starting from the second as an array

  if [[ ${#files[@]} == 0 ]]; then
    printf "%sError: At least one file path is required.%s\n" "${_COLOR_FAILED}" "${_COLOR_DEFAULT}"
    printf "%sUsage: %s <test_file.sh>%s\n" "${_COLOR_DEFAULT}" "$0" "${_COLOR_DEFAULT}"
    exit 1
  fi

  for test_file in "${files[@]}"; do
    if [[ ! -f $test_file ]]; then
      continue
    fi
    # shellcheck disable=SC1090
    #shellcheck source=/dev/null
    source "$test_file"

    Runner::runSetUpBeforeScript
    Runner::callTestFunctions "$test_file" "$filter"
    if [ "$PARALLEL_RUN" = true ] ; then
      wait
    fi
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

_FILTER=""
_FILES=()

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

Runner::loadTestFiles "$_FILTER" "${_FILES[@]}"

