#!/bin/bash

_START_TIME=$(date +%s%N);

function Console::renderResult() {
  if [[ "$(State::isDuplicatedTestFunctionsFound)" == true ]]; then
    printf "%s> Duplicate test functions found%s\n" "${_COLOR_FAILED}" "${_COLOR_DEFAULT}"
    return
  fi

  local tests_passed=$1
  local tests_failed=$2
  local assertions_passed=$3
  local assertions_failed=$4

  echo ""

  local total_tests=$((tests_passed + tests_failed))
  local total_assertions=$((assertions_passed + assertions_failed))

  printf "%sTests:     %s" "$_COLOR_FAINT" "$_COLOR_DEFAULT"
  if [[ $tests_passed -gt 0 ]] || [[ $assertions_passed -gt 0 ]]; then
    printf " %s%s passed%s," "$_COLOR_PASSED" "$tests_passed" "$_COLOR_DEFAULT"
  fi
  if [[ $tests_failed -gt 0 ]]; then
    printf " %s%s failed%s," "$_COLOR_FAILED" "$tests_failed" "$_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_tests"


  printf "%sAssertions:%s" "$_COLOR_FAINT" "$_COLOR_DEFAULT"
  if [[ $tests_passed -gt 0 ]] || [[ $assertions_passed -gt 0 ]]; then
      printf " %s%s passed%s," "$_COLOR_PASSED" "$assertions_passed" "$_COLOR_DEFAULT"
  fi
  if [[ $tests_failed -gt 0 ]]; then
    printf " %s%s failed%s," "$_COLOR_FAILED" "$assertions_failed" "$_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_assertions"

  if [[ "$tests_failed" -gt 0 ]]; then
    Console::printExecutionTime
    exit 1
  fi

  printf "%s%s%s\n" "$_COLOR_ALL_PASSED" "All tests passed" "$_COLOR_DEFAULT"
  Console::printExecutionTime
  exit 0
}

function Console::printExecutionTime() {
  if [[ "$_OS" != "OSX" ]]; then
    _EXECUTION_TIME=$((($(date +%s%N) - "$_START_TIME") / 1000000))
    printf "${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" "Time taken: ${_EXECUTION_TIME} ms"
  fi
}

function Console::printSuccessfulTest() {
  local test_name=$1
  printf "%s✓ Passed%s: %s\n" "$_COLOR_PASSED" "$_COLOR_DEFAULT" "${test_name}"
}

function Console::printFailedTest() {
  local test_name=$1
  local expected=$2
  local failure_condition_message=$3
  local actual=$4

  printf "\
${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s
    ${_COLOR_FAINT}Expected${_COLOR_DEFAULT} ${_COLOR_BOLD}'%s'${_COLOR_DEFAULT}
    ${_COLOR_FAINT}%s${_COLOR_DEFAULT} ${_COLOR_BOLD}'%s'${_COLOR_DEFAULT}\n"\
    "${test_name}" "${expected}" "${failure_condition_message}" "${actual}"
}

function Console::printErrorTest() {
  local test_name=$1
  local error_code=$2

  printf "${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s with error code %s\n" "${test_name}" "${error_code}"
}
