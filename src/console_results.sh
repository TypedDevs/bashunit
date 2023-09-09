#!/bin/bash

export renderResult
export printSuccessfulTest

_TESTS_PASSED=0
_TESTS_FAILED=0
_ASSERTIONS_PASSED=0
_ASSERTIONS_FAILED=0

function renderResult() {
  local testsPassed=$1
  local testsFailed=$2
  local assertionsPassed=$3
  local assertionsFailed=$4

  echo ""
  local totalTests=$((testsPassed + testsFailed))
  local totalAssertions=$((assertionsPassed + assertionsFailed))

  printf "%sTests:     %s" "$COLOR_FAINT" "$COLOR_DEFAULT"
  if [[ $assertionsPassed -gt 0 ]]; then
    printf " %s%s passed%s," "$COLOR_PASSED" "$testsPassed" "$COLOR_DEFAULT"
  fi
  if [[ $testsFailed -gt 0 ]]; then
    printf " %s%s failed%s," "$COLOR_FAILED" "$testsFailed" "$COLOR_DEFAULT"
  fi
  printf " %s total\n" "$totalTests"


  printf "%sAssertions:%s" "$COLOR_FAINT" "$COLOR_DEFAULT"
  if [[ $assertionsPassed -gt 0 ]]; then
      printf " %s%s passed%s," "$COLOR_PASSED" "$assertionsPassed" "$COLOR_DEFAULT"
  fi
  if [[ $testsFailed -gt 0 ]]; then
    printf " %s%s failed%s," "$COLOR_FAILED" "$assertionsFailed" "$COLOR_DEFAULT"
  fi
  printf " %s total\n" "$totalAssertions"

  if [[ "$testsFailed" -gt 0 ]]; then
    printExecTime
    exit 1
  fi

  printf "%s%s%s\n" "$COLOR_ALL_PASSED" "All tests passed" "$COLOR_DEFAULT"
  printExecTime
  exit 0
}

function printExecTime() {
  if [[ $OS != "OSX" ]]; then
    _TIME_TERMINATION=$((($(date +%s%N) - "$_TIME_START") / 1000000))
    printf "${COLOR_BOLD}%s${COLOR_DEFAULT}\n" "Time taken: ${_TIME_TERMINATION} ms"
  fi
}

function printSuccessfulTest() {
  testName=$1
  printf "${COLOR_PASSED}✓ Passed${COLOR_DEFAULT}: %s\n" "${testName}"
}

function printFailedTest() {
  testName=$1
  expected=$2
  failureConditionMessage=$3
  actual=$4

  printf "\
${COLOR_FAILED}✗ Failed${COLOR_DEFAULT}: %s
    ${COLOR_FAINT}Expected${COLOR_DEFAULT} ${COLOR_BOLD}'%s'${COLOR_DEFAULT}
    ${COLOR_FAINT}%s${COLOR_DEFAULT} ${COLOR_BOLD}'%s'${COLOR_DEFAULT}\n"\
    "${testName}" "${expected}" "${failureConditionMessage}" "${actual}"

}

# Set a trap to call renderResult when the script exits
trap 'renderResult $_TESTS_PASSED $_TESTS_FAILED $_ASSERTIONS_PASSED $_ASSERTIONS_FAILED' EXIT
