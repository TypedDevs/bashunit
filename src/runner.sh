#!/bin/bash

# shellcheck disable=SC2317

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
    if [[ "$_SIMPLE_OUTPUT" == false ]]; then
      echo "Running $script"
    fi

    Helper::checkDuplicateFunctions "$script"

    for function_name in "${functions_to_run[@]}"; do
      Runner::runTest "$function_name"

      unset "$function_name"
    done
  fi
}

function Runner::parseExecutionResult() {
  local execution_result=$1

  local assertions_failed
  assertions_failed=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_FAILED=([0-9]*)##.*/\1/g'\
  )

  local assertions_passed
  assertions_passed=$(\
    echo "$execution_result" |\
    tail -n 1 |\
    sed -E -e 's/.*##ASSERTIONS_PASSED=([0-9]*)##.*/\1/g'\
  )

  _ASSERTIONS_PASSED=$((_ASSERTIONS_PASSED + assertions_passed))
  _ASSERTIONS_FAILED=$((_ASSERTIONS_FAILED + assertions_failed))

  local print_execution_result
  print_execution_result="$(echo "$execution_result" | sed '$ d')"

  if [ -n "$print_execution_result" ]; then
    echo "$print_execution_result"
  fi
}

function Runner::runTest() {
  local function_name="$1"
  local current_assertions_failed
  local test_execution_result
  current_assertions_failed="$(state::get_assertions_failed)"

  test_execution_result=$(
    state::initialize_assertions_count

    set -e
    Runner::runSetUp
    "$function_name"
    Runner::runTearDown

    State::exportAssertionsCount
  )
  local test_result_code=$?
  Runner::parseExecutionResult "$test_execution_result"

  if [[ "$current_assertions_failed" != "$(state::get_assertions_failed)" ]]; then
    state::add_tests_failed
    return
  fi

  if [[ $test_result_code -ne 0 ]]; then
    state::add_tests_failed
    Console::printErrorTest "$function_name" "$test_result_code"
    return
  fi

  local label="${3:-$(Helper::normalizeTestFunctionName "$function_name")}"
  Console::printSuccessfulTest "${label}"
  state::add_tests_passed
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
