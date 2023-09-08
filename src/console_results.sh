export renderResult

function renderResult() {
  local totalTests=$1
  local totalPassed=$2
  local totalFailed=$3

  echo ""
  local totalAssertions=$((totalPassed + totalFailed))
  printf "\
${COLOR_FAINT}Total tests:${COLOR_DEFAULT} ${COLOR_BOLD}${totalTests}${COLOR_DEFAULT}
${COLOR_FAINT}Total assertions:${COLOR_DEFAULT} ${COLOR_BOLD}${totalAssertions}${COLOR_DEFAULT}\n"

  if [ "$totalFailed" -gt 0 ]; then
    printf "${COLOR_FAINT}Total assertions failed:${COLOR_DEFAULT} ${COLOR_BOLD}${COLOR_FAILED}${totalFailed}${COLOR_DEFAULT}\n"
    printExecTime
    exit 1
  else
    printf "${COLOR_ALL_PASSED}All assertions passed.${COLOR_DEFAULT}\n"
  fi

  printExecTime
  exit 0
}

function printExecTime() {
  if [[ $OS != "OSX" ]]; then
    _TIME_TERMINATION=$((($(date +%s%N) - $_TIME_START)/1000000))
    printf "${COLOR_BOLD}%s${COLOR_DEFAULT}\n" "Time taken: ${_TIME_TERMINATION} ms"
  fi
}

# Set a trap to call renderResult when the script exits
trap 'renderResult $_TOTAL_TESTS $_TOTAL_ASSERTIONS_PASSED $_TOTAL_ASSERTIONS_FAILED' EXIT
