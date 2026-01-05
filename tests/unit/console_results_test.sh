#!/usr/bin/env bash

# Helper to set both mock and actual variable for state values
function set_state_value() {
  local getter_name=$1
  local value=$2
  local var_name

  # Extract variable name from getter function name
  case "$getter_name" in
    bashunit::state::get_tests_passed) var_name="_BASHUNIT_TESTS_PASSED" ;;
    bashunit::state::get_tests_failed) var_name="_BASHUNIT_TESTS_FAILED" ;;
    bashunit::state::get_tests_skipped) var_name="_BASHUNIT_TESTS_SKIPPED" ;;
    bashunit::state::get_tests_incomplete) var_name="_BASHUNIT_TESTS_INCOMPLETE" ;;
    bashunit::state::get_tests_snapshot) var_name="_BASHUNIT_TESTS_SNAPSHOT" ;;
    bashunit::state::get_assertions_passed) var_name="_BASHUNIT_ASSERTIONS_PASSED" ;;
    bashunit::state::get_assertions_failed) var_name="_BASHUNIT_ASSERTIONS_FAILED" ;;
    bashunit::state::get_assertions_skipped) var_name="_BASHUNIT_ASSERTIONS_SKIPPED" ;;
    bashunit::state::get_assertions_incomplete) var_name="_BASHUNIT_ASSERTIONS_INCOMPLETE" ;;
    bashunit::state::get_assertions_snapshot) var_name="_BASHUNIT_ASSERTIONS_SNAPSHOT" ;;
    bashunit::state::is_duplicated_test_functions_found) var_name="_BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND" ;;
    bashunit::state::get_duplicated_function_names) var_name="_BASHUNIT_DUPLICATED_FUNCTION_NAMES" ;;
    bashunit::state::get_file_with_duplicated_function_names)
      var_name="_BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES" ;;
  esac

  # Set the actual variable
  eval "$var_name='$value'"
  # Mock the getter function
  bashunit::mock "$getter_name" echo "$value"
}

function mock_all_state_getters() {
  set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
  set_state_value "bashunit::state::get_duplicated_function_names" ""
  set_state_value "bashunit::state::get_file_with_duplicated_function_names" ""
  set_state_value "bashunit::state::get_tests_passed" "0"
  set_state_value "bashunit::state::get_tests_failed" "0"
  set_state_value "bashunit::state::get_tests_skipped" "0"
  set_state_value "bashunit::state::get_tests_incomplete" "0"
  set_state_value "bashunit::state::get_tests_snapshot" "0"
  set_state_value "bashunit::state::get_assertions_passed" "0"
  set_state_value "bashunit::state::get_assertions_failed" "0"
  set_state_value "bashunit::state::get_assertions_skipped" "0"
  set_state_value "bashunit::state::get_assertions_incomplete" "0"
  set_state_value "bashunit::state::get_assertions_snapshot" "0"

  # Also set actual state variables for direct access optimization
  _BASHUNIT_TESTS_PASSED=0
  _BASHUNIT_TESTS_FAILED=0
  _BASHUNIT_TESTS_SKIPPED=0
  _BASHUNIT_TESTS_INCOMPLETE=0
  _BASHUNIT_TESTS_SNAPSHOT=0
  _BASHUNIT_ASSERTIONS_PASSED=0
  _BASHUNIT_ASSERTIONS_FAILED=0
  _BASHUNIT_ASSERTIONS_SKIPPED=0
  _BASHUNIT_ASSERTIONS_INCOMPLETE=0
  _BASHUNIT_ASSERTIONS_SNAPSHOT=0
  _BASHUNIT_DUPLICATED_TEST_FUNCTIONS_FOUND=false
  _BASHUNIT_DUPLICATED_FUNCTION_NAMES=""
  _BASHUNIT_FILE_WITH_DUPLICATED_FUNCTION_NAMES=""
}

function test_not_render_passed_when_no_passed_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_passed" "0"
    set_state_value "bashunit::state::get_assertions_passed" "0"
    _BASHUNIT_TESTS_PASSED=0
    _BASHUNIT_ASSERTIONS_PASSED=0

    bashunit::console_results::render_result || true
  )

  assert_not_matches "Tests:[^\n]*passed[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*passed[^\n]*total" "$render_result"
}

function test_render_passed_when_passed_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_passed" "32"
    set_state_value "bashunit::state::get_assertions_passed" "0"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*32 passed[^\n]*32 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 passed[^\n]*0 total" "$render_result"
}

function test_render_passed_when_passed_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_passed" "0"
    set_state_value "bashunit::state::get_assertions_passed" "24"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*0 passed[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*24 passed[^\n]*24 total" "$render_result"
}

function test_not_render_skipped_when_no_skipped_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_skipped" "0"
    set_state_value "bashunit::state::get_assertions_skipped" "0"

    bashunit::console_results::render_result || true
  )

  assert_not_matches "Tests:[^\n]*skipped[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*skipped[^\n]*total" "$render_result"
}

function test_render_skipped_when_skipped_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_skipped" "11"
    set_state_value "bashunit::state::get_assertions_skipped" "0"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*11 skipped[^\n]*11 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 skipped[^\n]*0 total" "$render_result"
}

function test_render_skipped_when_skipped_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_skipped" "0"
    set_state_value "bashunit::state::get_assertions_skipped" "12"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*0 skipped[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*12 skipped[^\n]*12 total" "$render_result"
}

function test_not_render_incomplete_when_no_incomplete_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_incomplete" "0"
    set_state_value "bashunit::state::get_assertions_incomplete" "0"

    bashunit::console_results::render_result || true
  )

  assert_not_matches "Tests:[^\n]*incomplete[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*incomplete[^\n]*total" "$render_result"
}

function test_render_incomplete_when_incomplete_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_incomplete" "15"
    set_state_value "bashunit::state::get_assertions_incomplete" "0"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*15 incomplete[^\n]*15 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 incomplete[^\n]*0 total" "$render_result"
}

function test_render_incomplete_when_incomplete_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_incomplete" "0"
    set_state_value "bashunit::state::get_assertions_incomplete" "20"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*0 incomplete[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*20 incomplete[^\n]*20 total" "$render_result"
}

function test_not_render_snapshot_when_no_snapshot_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_snapshot" "0"
    set_state_value "bashunit::state::get_assertions_snapshot" "0"

    bashunit::console_results::render_result || true
  )

  assert_not_matches "Tests:[^\n]*snapshot[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*snapshot[^\n]*total" "$render_result"
}

function test_render_snapshot_when_snapshot_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_snapshot" "16"
    set_state_value "bashunit::state::get_assertions_snapshot" "0"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*16 snapshot[^\n]*16 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 snapshot[^\n]*0 total" "$render_result"
}

function test_render_snapshot_when_snapshot_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_snapshot" "0"
    set_state_value "bashunit::state::get_assertions_snapshot" "17"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*0 snapshot[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*17 snapshot[^\n]*17 total" "$render_result"
}

function test_not_render_failed_when_not_failed_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_failed" "0"
    set_state_value "bashunit::state::get_assertions_failed" "0"

    bashunit::console_results::render_result || true
  )

  assert_not_matches "Tests:[^\n]*failed[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*failed[^\n]*total" "$render_result"
}

function test_render_failed_when_failed_tests() {
  set +e

  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_failed" "42"
    set_state_value "bashunit::state::get_assertions_failed" "0"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*42 failed[^\n]*42 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 failed[^\n]*0 total" "$render_result"
}

function test_render_failed_when_failed_assertions() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_failed" "0"
    set_state_value "bashunit::state::get_assertions_failed" "666"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:[^\n]*0 failed[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*666 failed[^\n]*666 total" "$render_result"
}

function test_total_tests_is_the_sum_of_passed_skipped_incomplete_snapshot_and_failed_tests() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_tests_passed" "4"
    set_state_value "bashunit::state::get_tests_skipped" "5"
    set_state_value "bashunit::state::get_tests_incomplete" "7"
    set_state_value "bashunit::state::get_tests_snapshot" "11"
    set_state_value "bashunit::state::get_tests_failed" "2"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:.*29 total.*Assertions:.*0 total" "$render_result"
}

function test_total_asserts_is_the_sum_of_passed_skipped_incomplete_snapshot_and_failed_asserts() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::get_assertions_passed" "4"
    set_state_value "bashunit::state::get_assertions_skipped" "5"
    set_state_value "bashunit::state::get_assertions_incomplete" "7"
    set_state_value "bashunit::state::get_assertions_snapshot" "11"
    set_state_value "bashunit::state::get_assertions_failed" "2"

    bashunit::console_results::render_result || true
  )

  assert_matches "Tests:.*0 total.*Assertions:.*29 total" "$render_result"
}

function test_render_execution_time() {
  local render_result
  render_result=$(
    # shellcheck disable=SC2034
    BASHUNIT_SHOW_EXECUTION_TIME=true

    bashunit::console_results::render_result || true
  )
  assert_matches "Time taken: ([[:digit:]]+(\\.[[:digit:]]+)?(ms|s)|[[:digit:]]+m [[:digit:]]+s)" "$render_result"
}

function test_not_render_execution_time() {
  local render_result
  render_result=$(
    # shellcheck disable=SC2034
    BASHUNIT_SHOW_EXECUTION_TIME=false

    bashunit::console_results::render_result || true
  )
  assert_not_matches "Time taken" "$render_result"
}

function test_render_execution_time_on_osx_without_perl() {
  if ! bashunit::check_os::is_macos; then
    bashunit::skip && return
  fi

  mock_macos
  bashunit::mock bashunit::dependencies::has_perl mock_false

  _BASHUNIT_START_TIME=1727771758.0664479733

  local render_result
  render_result=$(
    bashunit::console_results::render_result || true
  )

  assert_matches "Time taken: ([[:digit:]]+(\\.[[:digit:]]+)?(ms|s)|[[:digit:]]+m [[:digit:]]+s)" "$render_result"
}

function test_render_execution_time_on_osx_with_perl() {
  if ! bashunit::check_os::is_macos; then
    bashunit::skip && return
  fi

  local render_result
  mock_macos
  bashunit::mock bashunit::dependencies::has_adjtimex mock_false
  bashunit::mock bashunit::dependencies::has_perl mock_true
  _BASHUNIT_START_TIME="1726393394574382186"
  bashunit::mock perl <<< "1726393394574372186"
  bashunit::mock uname <<< "Darwin"
  render_result=$(
  bashunit::mock perl <<< "1726393394574372186";

    bashunit::console_results::render_result || true
  )

  assert_matches "Time taken: [[:digit:]]+(\\.[[:digit:]]+)?ms" "$render_result"
}

function test_render_execution_time_in_minutes() {
  local render_result
  render_result=$(
    # shellcheck disable=SC2034
    BASHUNIT_SHOW_EXECUTION_TIME=true
    bashunit::mock bashunit::clock::total_runtime_in_milliseconds echo "121000"
    bashunit::console_results::print_execution_time
  )
  assert_matches "Time taken: 2m 1s" "$render_result"
}

function test_render_execution_time_in_minutes_exact_minute() {
  local render_result
  render_result=$(
    # shellcheck disable=SC2034
    BASHUNIT_SHOW_EXECUTION_TIME=true
    bashunit::mock bashunit::clock::total_runtime_in_milliseconds echo "120000"
    bashunit::console_results::print_execution_time
  )
  assert_matches "Time taken: 2m 0s" "$render_result"
}

function test_render_file_with_duplicated_functions_if_found_true() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "true"
    set_state_value "bashunit::state::get_duplicated_function_names" "duplicate_function_name"
    set_state_value "bashunit::state::get_file_with_duplicated_function_names" "duplicate_file_name.sh"

    bashunit::console_results::render_result || true
  )

  assert_contains "Duplicate test functions found" "$render_result"
  assert_contains "File with duplicate functions: duplicate_file_name.sh" "$render_result"
  assert_contains "Duplicate functions: duplicate_function_name" "$render_result"
}

function test_not_render_file_with_duplicated_functions_if_found_false() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
    set_state_value "bashunit::state::get_duplicated_function_names" "duplicate_function_name"
    set_state_value "bashunit::state::get_file_with_duplicated_function_names" "duplicate_file_name.sh"

    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "File with duplicate functions: duplicate_file_name.sh" "$render_result"
  assert_not_contains "Duplicate functions: duplicate_function_name" "$render_result"
}

function test_only_render_error_result_when_some_duplicated_fails() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "true"
    set_state_value "bashunit::state::get_tests_failed" "1"
    set_state_value "bashunit::state::get_tests_incomplete" "4"
    set_state_value "bashunit::state::get_tests_snapshot" "7"
    set_state_value "bashunit::state::get_tests_skipped" "2"
    set_state_value "bashunit::state::get_tests_passed" "3"

    bashunit::console_results::render_result || true
  )

  assert_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some snapshots created" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
  assert_not_contains "No tests found" "$render_result"
}

function test_only_render_error_result_when_some_test_fails() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
    set_state_value "bashunit::state::get_tests_failed" "1"
    set_state_value "bashunit::state::get_tests_incomplete" "4"
    set_state_value "bashunit::state::get_tests_snapshot" "7"
    set_state_value "bashunit::state::get_tests_skipped" "2"
    set_state_value "bashunit::state::get_tests_passed" "3"

    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some snapshots created" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
  assert_not_contains "No tests found" "$render_result"
}

function test_only_render_incomplete_result_when_no_test_fails_and_some_incomplete() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
    set_state_value "bashunit::state::get_tests_failed" "0"
    set_state_value "bashunit::state::get_tests_incomplete" "4"
    set_state_value "bashunit::state::get_tests_snapshot" "7"
    set_state_value "bashunit::state::get_tests_skipped" "2"
    set_state_value "bashunit::state::get_tests_passed" "3"

    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some snapshots created" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
  assert_not_contains "No tests found" "$render_result"
}

function test_only_render_skipped_result_when_no_test_fails_nor_incomplete_and_some_skipped() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
    set_state_value "bashunit::state::get_tests_failed" "0"
    set_state_value "bashunit::state::get_tests_incomplete" "0"
    set_state_value "bashunit::state::get_tests_snapshot" "7"
    set_state_value "bashunit::state::get_tests_skipped" "2"
    set_state_value "bashunit::state::get_tests_passed" "3"

    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some snapshots created" "$render_result"
  assert_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
  assert_not_contains "No tests found" "$render_result"
}

function test_only_render_snapshot_result_when_no_test_fails_nor_incomplete_nor_skipped_and_some_snapshot() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
    set_state_value "bashunit::state::get_tests_failed" "0"
    set_state_value "bashunit::state::get_tests_incomplete" "0"
    set_state_value "bashunit::state::get_tests_snapshot" "7"
    set_state_value "bashunit::state::get_tests_skipped" "0"
    set_state_value "bashunit::state::get_tests_passed" "3"

    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_contains "Some snapshots created" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
  assert_not_contains "No tests found" "$render_result"
}

function test_only_render_success_result_when_all_tests_passes() {
  local render_result
  render_result=$(
    mock_all_state_getters
    set_state_value "bashunit::state::is_duplicated_test_functions_found" "false"
    set_state_value "bashunit::state::get_tests_failed" "0"
    set_state_value "bashunit::state::get_tests_incomplete" "0"
    set_state_value "bashunit::state::get_tests_snapshot" "0"
    set_state_value "bashunit::state::get_tests_skipped" "0"
    set_state_value "bashunit::state::get_tests_passed" "3"

    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some snapshots created" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_contains "All tests passed" "$render_result"
  assert_not_contains "No tests found" "$render_result"
}

function test_no_tests_found() {
  local render_result
  render_result=$(
    mock_all_state_getters
    bashunit::console_results::render_result || true
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some snapshots created" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
  assert_contains "No tests found" "$render_result"
}

function test_print_successful_test_output_no_args() {
  original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=false
  export TERMINAL_WIDTH=120

  local test_name="a custom test"

  assert_matches \
    "✓ Passed.*$test_name.*12ms" \
    "$(bashunit::console_results::print_successful_test "$test_name" "12")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}

function test_print_successful_test_output_with_args() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=false
  export TERMINAL_WIDTH=120

  local test_name="a custom test"
  local data="foo"

  assert_matches \
    "✓ Passed.*$test_name \('$data'\).*12ms" \
    "$(bashunit::console_results::print_successful_test "$test_name" "12" "$data")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}

function test_print_successful_test_output_in_seconds() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=false
  export TERMINAL_WIDTH=120

  local test_name="a test taking seconds"

  assert_matches \
    "✓ Passed.*$test_name.*5.12s" \
    "$(bashunit::console_results::print_successful_test "$test_name" "5123")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}

function test_print_successful_test_output_in_minutes() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=false
  export TERMINAL_WIDTH=120

  local test_name="a test taking minutes"

  assert_matches \
    "✓ Passed.*$test_name.*1m 3s" \
    "$(bashunit::console_results::print_successful_test "$test_name" "63000")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}

function test_print_successful_test_output_in_minutes_exact() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=false
  export TERMINAL_WIDTH=120

  local test_name="a test taking exact minutes"

  assert_matches \
    "✓ Passed.*$test_name.*2m 0s" \
    "$(bashunit::console_results::print_successful_test "$test_name" "120000")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}

function test_print_hook_running_produces_no_output() {
  local output
  output=$(bashunit::console_results::print_hook_running "set_up_before_script")

  assert_empty "$output"
}

function test_print_hook_completed_output_milliseconds() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  local original_parallel_run=$BASHUNIT_PARALLEL_RUN
  export BASHUNIT_SIMPLE_OUTPUT=false
  export BASHUNIT_PARALLEL_RUN=false
  export TERMINAL_WIDTH=80

  local output
  output=$(bashunit::console_results::print_hook_completed "set_up_before_script" "12")

  assert_matches "● set_up_before_script.*12ms" "$output"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
  export BASHUNIT_PARALLEL_RUN=$original_parallel_run
}

function test_print_hook_completed_output_seconds() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  local original_parallel_run=$BASHUNIT_PARALLEL_RUN
  export BASHUNIT_SIMPLE_OUTPUT=false
  export BASHUNIT_PARALLEL_RUN=false
  export TERMINAL_WIDTH=80

  local output
  output=$(bashunit::console_results::print_hook_completed "set_up_before_script" "2340")

  assert_matches "● set_up_before_script.*2.34s" "$output"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
  export BASHUNIT_PARALLEL_RUN=$original_parallel_run
}

function test_print_hook_completed_output_minutes() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  local original_parallel_run=$BASHUNIT_PARALLEL_RUN
  export BASHUNIT_SIMPLE_OUTPUT=false
  export BASHUNIT_PARALLEL_RUN=false
  export TERMINAL_WIDTH=80

  local output
  output=$(bashunit::console_results::print_hook_completed "tear_down_after_script" "125000")

  assert_matches "● tear_down_after_script.*2m 5s" "$output"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
  export BASHUNIT_PARALLEL_RUN=$original_parallel_run
}

function test_print_hook_completed_suppressed_in_simple_mode() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=true

  local output
  output=$(bashunit::console_results::print_hook_completed "set_up_before_script" "12")

  assert_empty "$output"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}
