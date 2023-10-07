#!/bin/bash

_START_TIME=$(date +%s%N);
_SUCCESSFUL_TEST_COUNT=0

function console_results::render_result() {
  if [[ "$(state::is_duplicated_test_functions_found)" == true ]]; then
    console_results::print_execution_time
    printf "%s%s%s\n" "${_COLOR_RETURN_ERROR}" "Duplicate test functions found" "${_COLOR_DEFAULT}"
    exit 1
  fi

  echo ""

  local total_tests=0
  ((total_tests+=$(state::get_tests_passed)))
  ((total_tests+=$(state::get_tests_skipped)))
  ((total_tests+=$(state::get_tests_incomplete)))
  ((total_tests+=$(state::get_tests_failed)))
  local total_assertions=0
  ((total_assertions+=$(state::get_assertions_passed)))
  ((total_assertions+=$(state::get_assertions_skipped)))
  ((total_assertions+=$(state::get_assertions_incomplete)))
  ((total_assertions+=$(state::get_assertions_failed)))

  printf "%sTests:     %s" "$_COLOR_FAINT" "$_COLOR_DEFAULT"
  if [[ "$(state::get_tests_passed)" -gt 0 ]] || [[ "$(state::get_assertions_passed)" -gt 0 ]]; then
    printf " %s%s passed%s," "$_COLOR_PASSED" "$(state::get_tests_passed)" "$_COLOR_DEFAULT"
  fi
  if [[ "$(state::get_tests_skipped)" -gt 0 ]] || [[ "$(state::get_assertions_skipped)" -gt 0 ]]; then
    printf " %s%s skipped%s," "$_COLOR_SKIPPED" "$(state::get_tests_skipped)" "$_COLOR_DEFAULT"
  fi
  if [[ "$(state::get_tests_incomplete)" -gt 0 ]] || [[ "$(state::get_assertions_incomplete)" -gt 0 ]]; then
    printf " %s%s incomplete%s," "$_COLOR_INCOMPLETE" "$(state::get_tests_incomplete)" "$_COLOR_DEFAULT"
  fi
  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
    printf " %s%s failed%s," "$_COLOR_FAILED" "$(state::get_tests_failed)" "$_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_tests"

  printf "%sAssertions:%s" "$_COLOR_FAINT" "$_COLOR_DEFAULT"
  if [[ "$(state::get_tests_passed)" -gt 0 ]] || [[ "$(state::get_assertions_passed)" -gt 0 ]]; then
      printf " %s%s passed%s," "$_COLOR_PASSED" "$(state::get_assertions_passed)" "$_COLOR_DEFAULT"
  fi
  if [[ "$(state::get_tests_skipped)" -gt 0 ]] || [[ "$(state::get_assertions_skipped)" -gt 0 ]]; then
    printf " %s%s skipped%s," "$_COLOR_SKIPPED" "$(state::get_assertions_skipped)" "$_COLOR_DEFAULT"
  fi
  if [[ "$(state::get_tests_incomplete)" -gt 0 ]] || [[ "$(state::get_assertions_incomplete)" -gt 0 ]]; then
    printf " %s%s incomplete%s," "$_COLOR_INCOMPLETE" "$(state::get_assertions_incomplete)" "$_COLOR_DEFAULT"
  fi
  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
    printf " %s%s failed%s," "$_COLOR_FAILED" "$(state::get_assertions_failed)" "$_COLOR_DEFAULT"
  fi
  printf " %s total\n" "$total_assertions"

  if [[ "$(state::get_tests_failed)" -gt 0 ]]; then
    printf "%s%s%s\n" "$_COLOR_RETURN_ERROR" "Some tests failed" "$_COLOR_DEFAULT"
    console_results::print_execution_time
    exit 1
  fi

  if [[ "$(state::get_tests_incomplete)" -gt 0 ]]; then
    printf "%s%s%s\n" "$_COLOR_RETURN_INCOMPLETE" "Some tests incomplete" "$_COLOR_DEFAULT"
    console_results::print_execution_time
    exit 0
  fi

  if [[ "$(state::get_tests_skipped)" -gt 0 ]]; then
    printf "%s%s%s\n" "$_COLOR_RETURN_SKIPPED" "Some tests skipped" "$_COLOR_DEFAULT"
    console_results::print_execution_time
    exit 0
  fi

  printf "%s%s%s\n" "$_COLOR_RETURN_SUCCESS" "All tests passed" "$_COLOR_DEFAULT"
  console_results::print_execution_time
  exit 0
}

function console_results::print_execution_time() {
  if [[ "$_OS" != "OSX" ]]; then
    _EXECUTION_TIME=$((($(date +%s%N) - "$_START_TIME") / 1000000))
    printf "${_COLOR_BOLD}%s${_COLOR_DEFAULT}\n" "Time taken: ${_EXECUTION_TIME} ms"
  fi
}

function console_results::print_successful_test() {
  ((_SUCCESSFUL_TEST_COUNT++))

  if [[ "$SIMPLE_OUTPUT" == true ]]; then
    if (( _SUCCESSFUL_TEST_COUNT % 50 != 0 )); then
      printf "."
    else
      echo "."
    fi
  else
    local test_name=$1
    printf "%s✓ Passed%s: %s\n" "$_COLOR_PASSED" "$_COLOR_DEFAULT" "${test_name}"
  fi
}

function console_results::print_failed_test() {
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

function console_results::print_skipped_test() {
  local test_name=$1
  local reason=$2

  printf "${_COLOR_SKIPPED}↷ Skipped${_COLOR_DEFAULT}: %s\n" "${test_name}"

  if [[ -n "$reason" ]]; then
    printf "${_COLOR_FAINT}    %s${_COLOR_DEFAULT}\n" "${reason}"
  fi
}

function console_results::print_incomplete_test() {
  local test_name=$1
  local pending=$2

  printf "${_COLOR_INCOMPLETE}✒ Incomplete${_COLOR_DEFAULT}: %s\n" "${test_name}"

  if [[ -n "$pending" ]]; then
    printf "${_COLOR_FAINT}    %s${_COLOR_DEFAULT}\n" "${pending}"
  fi
}

function console_results::print_error_test() {
  local test_name="${3:-$(helper::normalize_test_function_name "$1")}"
  local error_code=$2

  printf "${_COLOR_FAILED}✗ Failed${_COLOR_DEFAULT}: %s with error code %s\n" "${test_name}" "${error_code}"
}
