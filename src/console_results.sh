#!/bin/bash

export renderResult
export printSuccessfulTest

_TOTAL_TESTS_PASSED=0
_TOTAL_TESTS_FAILED=0
_TOTAL_ASSERTIONS_PASSED=0
_TOTAL_ASSERTIONS_FAILED=0

function renderResult() {
  local totalTestsPassed=$1
  local totalTestsFailed=$2
  local totalAssertionsPassed=$3
  local totalAssertionsFailed=$4

  echo ""
  local totalTests=$((totalTestsPassed + totalTestsFailed))
  local totalAssertions=$((totalAssertionsPassed + totalAssertionsFailed))

  printf "%sTests:     %s" "$COLOR_FAINT" "$COLOR_DEFAULT"
  if [[ $totalAssertionsPassed -gt 0 ]]; then
    printf " %s%s passed%s," "$COLOR_PASSED" "$totalTestsPassed" "$COLOR_DEFAULT"
  fi
  if [[ $totalAssertionsFailed -gt 0 ]]; then
    printf " %s%s failed%s," "$COLOR_FAILED" "$totalTestsFailed" "$COLOR_DEFAULT"
  fi
  printf " %s total\n" "$totalTests"


  printf "%sAssertions:%s" "$COLOR_FAINT" "$COLOR_DEFAULT"
  if [[ $totalAssertionsPassed -gt 0 ]]; then
      printf " %s%s passed%s," "$COLOR_PASSED" "$totalAssertionsPassed" "$COLOR_DEFAULT"
  fi
  if [[ $totalAssertionsFailed -gt 0 ]]; then
    printf " %s%s failed%s," "$COLOR_FAILED" "$totalAssertionsFailed" "$COLOR_DEFAULT"
  fi
  printf " %s total\n" "$totalAssertions"


  if [ "$totalAssertionsFailed" -gt 0 ]; then
    printExecTime
    exit 1
  fi

  printf "${COLOR_ALL_PASSED}%s${COLOR_DEFAULT}\n" "All assertions passed."
  printExecTime
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
trap 'renderResult $_TOTAL_TESTS_PASSED $_TOTAL_TESTS_FAILED $_TOTAL_ASSERTIONS_PASSED $_TOTAL_ASSERTIONS_FAILED' EXIT
