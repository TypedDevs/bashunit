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
  local forward_stdout=$2
  local args=("${@:3}")

  local assert_fn=$original_assert_fn

  # Check if the function exists
  if ! type "$assert_fn" > /dev/null 2>&1; then
    assert_fn="assert_$assert_fn"
    if ! type "$assert_fn" > /dev/null 2>&1; then
      # Write into stderr
      echo "Function $original_assert_fn does not exist." 1>&2
      exit 127
    fi
  fi

  # Get the last argument safely by calculating the array length
  local last_index=$((${#args[@]} - 1))
  local last_arg="${args[$last_index]}"
  local inner_exit_code=0
  local bashunit_exit_code=0
  local output

  if [[ "$last_arg" == eval* ]]; then
    local callable_command="${last_arg#eval }"
    output=$(eval "$callable_command" 2>&1 || echo "inner_exit_code:$?")

    local last_line
    last_line=$(echo "$output" | tail -n 1)
    inner_exit_code=$(echo "$last_line" | grep -o 'inner_exit_code:[0-9]*' | cut -d':' -f2)
    if ! [[ $inner_exit_code =~ ^[0-9]+$ ]]; then
      inner_exit_code=1
    fi
    output=$(echo "$output" | sed '$d')

    # Remove the last argument and append the output
    args=("${args[@]:0:last_index}")
    args+=("$inner_exit_code")
  fi

  if [[ -n "$output" ]]; then
    [[ "$forward_stdout" == "true" ]] && echo "$output" 1>&1
    [[ "$assert_fn" == "assert_exit_code" ]] && assert_fn="assert_same"
  fi

  # Run the assertion function and write into stderr
  "$assert_fn" "${args[@]}" 1>&2
  bashunit_exit_code=$?

  if [[ "$(state::get_tests_failed)" -gt 0 ]] || [[ "$(state::get_assertions_failed)" -gt 0 ]]; then
    exit 1
  fi

  return "$bashunit_exit_code"
}
