#!/bin/bash

_TIME_START=$(date +%s%N);
_TESTS_PASSED=0
_TESTS_FAILED=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0

function renderResult() {
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
    printExecTime
    exit 1
  fi

  printf "%s%s%s\n" "$_COLOR_ALL_PASSED" "All tests passed" "$_COLOR_DEFAULT"
  printExecTime
  exit 0
}

function printExecTime() {
  if [[ $_OS != "OSX" ]]; then
    _TIME_TERMINATION=$((($(date +%s%N) - "$_TIME_START") / 1000000))
    printf "${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" "Time taken: ${_TIME_TERMINATION} ms"
  fi
}

function printSuccessfulTest() {
  local test_name=$1
  printf "${_COLOR_PASSED}✓ Passed${_COLOR_DEFAULT}: %s\n" "${test_name}"
}

function printFailedTest() {
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

# Set a trap to call renderResult when the script exits
trap 'renderResult $_TESTS_PASSED $_TESTS_FAILED $_ASSERTIONS_PASSED $_ASSERTIONS_FAILED' EXIT
