#!/bin/bash

function main::exec_tests() {
  local filter=$1
  local files=("${@:2}")

  local test_files=()
  while IFS= read -r line; do
    test_files+=("$line")
  done < <(helper::load_test_files "$filter" "${files[@]}")

  if [[ ${#test_files[@]} -eq 0 || -z "${test_files[0]}" ]]; then
    printf "%sError: At least one file path is required.%s\n" "${_COLOR_FAILED}" "${_COLOR_DEFAULT}"
    console_header::print_help
    exit 1
  fi

  console_header::print_version_with_env "$filter" "${test_files[@]}"
  runner::load_test_files "$filter" "${test_files[@]}"
  console_results::print_failing_tests_and_reset
  console_results::render_result
  exit_code=$?

  if [[ -n "$BASHUNIT_LOG_JUNIT" ]]; then
    logger::generate_junit_xml "$BASHUNIT_LOG_JUNIT"
  fi

  if [[ -n "$BASHUNIT_REPORT_HTML" ]]; then
    logger::generate_report_html "$BASHUNIT_REPORT_HTML"
  fi

  exit $exit_code
}

function main::exec_assert() {
  local original_assert_fn=$1
  local assert_fn=$original_assert_fn
  local args=("${@:2}")

  if ! type "$assert_fn" > /dev/null 2>&1; then
    # try again using prefix `assert_`
    assert_fn="assert_$assert_fn"
    if ! type "$assert_fn" > /dev/null 2>&1; then
      echo "Function $original_assert_fn does not exist."
      exit 127
    fi
  fi

  "$assert_fn" "${args[@]}"

  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
      exit 1
  fi
}
