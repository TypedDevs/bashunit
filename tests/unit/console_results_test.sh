#!/bin/bash

function mock_all_state_getters() {
  mock state::is_duplicated_test_functions_found echo false
  mock state::get_duplicated_function_names echo ""
  mock state::get_file_with_duplicated_function_names echo ""
  mock state::get_tests_passed echo 0
  mock state::get_tests_failed echo 0
  mock state::get_tests_skipped echo 0
  mock state::get_tests_incomplete echo 0
  mock state::get_tests_snapshot echo 0
  mock state::get_assertions_passed echo 0
  mock state::get_assertions_failed echo 0
  mock state::get_assertions_skipped echo 0
  mock state::get_assertions_incomplete echo 0
  mock state::get_assertions_snapshot echo 0
}

function test_not_render_passed_when_no_passed_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_passed echo 0
    mock state::get_assertions_passed echo 0

    console_results::render_result
  )

  assert_not_matches "Tests:[^\n]*passed[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*passed[^\n]*total" "$render_result"
}

function test_render_passed_when_passed_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_passed echo 32
    mock state::get_assertions_passed echo 0

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*32 passed[^\n]*32 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 passed[^\n]*0 total" "$render_result"
}

function test_render_passed_when_passed_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_passed echo 0
    mock state::get_assertions_passed echo 24

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*0 passed[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*24 passed[^\n]*24 total" "$render_result"
}

function test_not_render_skipped_when_no_skipped_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_skipped echo 0
    mock state::get_assertions_skipped echo 0

    console_results::render_result
  )

  assert_not_matches "Tests:[^\n]*skipped[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*skipped[^\n]*total" "$render_result"
}

function test_render_skipped_when_skipped_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_skipped echo 11
    mock state::get_assertions_skipped echo 0

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*11 skipped[^\n]*11 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 skipped[^\n]*0 total" "$render_result"
}

function test_render_skipped_when_skipped_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_skipped echo 0
    mock state::get_assertions_skipped echo 12

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*0 skipped[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*12 skipped[^\n]*12 total" "$render_result"
}

function test_not_render_incomplete_when_no_incomplete_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_incomplete echo 0
    mock state::get_assertions_incomplete echo 0

    console_results::render_result
  )

  assert_not_matches "Tests:[^\n]*incomplete[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*incomplete[^\n]*total" "$render_result"
}

function test_render_incomplete_when_incomplete_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_incomplete echo 15
    mock state::get_assertions_incomplete echo 0

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*15 incomplete[^\n]*15 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 incomplete[^\n]*0 total" "$render_result"
}

function test_render_incomplete_when_incomplete_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_incomplete echo 0
    mock state::get_assertions_incomplete echo 20

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*0 incomplete[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*20 incomplete[^\n]*20 total" "$render_result"
}

function test_not_render_snapshot_when_no_snapshot_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_snapshot echo 0
    mock state::get_assertions_snapshot echo 0

    console_results::render_result
  )

  assert_not_matches "Tests:[^\n]*snapshot[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*snapshot[^\n]*total" "$render_result"
}

function test_render_snapshot_when_snapshot_tests() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_snapshot echo 16
    mock state::get_assertions_snapshot echo 0

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*16 snapshot[^\n]*16 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 snapshot[^\n]*0 total" "$render_result"
}

function test_render_snapshot_when_snapshot_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_snapshot echo 0
    mock state::get_assertions_snapshot echo 17

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*0 snapshot[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*17 snapshot[^\n]*17 total" "$render_result"
}

function test_not_render_failed_when_not_failed_tests_nor_assertions() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_failed echo 0
    mock state::get_assertions_failed echo 0

    console_results::render_result
  )

  assert_not_matches "Tests:[^\n]*failed[^\n]*total" "$render_result"
  assert_not_matches "Assertions:[^\n]*failed[^\n]*total" "$render_result"
}

function test_render_failed_when_failed_tests() {
  set +e

  render_result=$(
    mock_all_state_getters
    mock state::get_tests_failed echo 42
    mock state::get_assertions_failed echo 0

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*42 failed[^\n]*42 total" "$render_result"
  assert_matches "Assertions:[^\n]*0 failed[^\n]*0 total" "$render_result"
}

function test_render_failed_when_failed_assertions() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_failed echo 0
    mock state::get_assertions_failed echo 666

    console_results::render_result
  )

  assert_matches "Tests:[^\n]*0 failed[^\n]*0 total" "$render_result"
  assert_matches "Assertions:[^\n]*666 failed[^\n]*666 total" "$render_result"
}

function test_total_tests_is_the_sum_of_passed_skipped_incomplete_snapshot_and_failed_tests() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_passed echo 4
    mock state::get_tests_skipped echo 5
    mock state::get_tests_incomplete echo 7
    mock state::get_tests_snapshot echo 11
    mock state::get_tests_failed echo 2

    console_results::render_result
  )

  assert_matches "Tests:.*29 total.*Assertions:.*0 total" "$render_result"
}

function test_total_asserts_is_the_sum_of_passed_skipped_incomplete_snapshot_and_failed_asserts() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_assertions_passed echo 4
    mock state::get_assertions_skipped echo 5
    mock state::get_assertions_incomplete echo 7
    mock state::get_assertions_snapshot echo 11
    mock state::get_assertions_failed echo 2

    console_results::render_result
  )

  assert_matches "Tests:.*0 total.*Assertions:.*29 total" "$render_result"
}

function test_render_execution_time() {
  local render_result
  render_result=$(
    # shellcheck disable=SC2034
    BASHUNIT_SHOW_EXECUTION_TIME=true

    console_results::render_result
  )
  assert_matches "Time taken: [[:digit:]]+ ms" "$render_result"
}

function test_not_render_execution_time() {
  local render_result
  render_result=$(
    # shellcheck disable=SC2034
    BASHUNIT_SHOW_EXECUTION_TIME=false

    console_results::render_result
  )
  assert_not_matches "Time taken" "$render_result"
}

function test_render_execution_time_on_osx_without_perl() {
  if check_os::is_windows; then
    skip
    return
  fi

  mock_macos
  mock dependencies::has_perl mock_false

  _START_TIME=1727771758.0664479733
  EPOCHREALTIME=1727780556.4266040325

  local render_result
  render_result=$(
    console_results::render_result
  )

  assert_matches "Time taken: [[:digit:]]+ ms" "$render_result"
}

function test_render_execution_time_on_osx_with_perl() {
  if check_os::is_windows; then
    skip
    return
  fi

  local render_result
  mock_macos
  mock dependencies::has_adjtimex mock_false
  mock dependencies::has_perl mock_true
  _START_TIME="1726393394574382186"
  mock perl echo "1726393394574372186"
  mock uname echo "Darwin"
  render_result=$(
  mock perl echo "1726393394574372186";

    console_results::render_result
  )

  assert_matches "Time taken: [[:digit:]]+ ms" "$render_result"
}

function test_render_file_with_duplicated_functions_if_found_true() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::is_duplicated_test_functions_found echo true
    mock state::get_duplicated_function_names echo "duplicate_function_name"
    mock state::get_file_with_duplicated_function_names echo "duplicate_file_name.sh"

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_duplicated_function_names echo "duplicate_function_name"
    mock state::get_file_with_duplicated_function_names echo "duplicate_file_name.sh"

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo true
    mock state::get_tests_failed echo 1
    mock state::get_tests_incomplete echo 4
    mock state::get_tests_snapshot echo 7
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 1
    mock state::get_tests_incomplete echo 4
    mock state::get_tests_snapshot echo 7
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 4
    mock state::get_tests_snapshot echo 7
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 0
    mock state::get_tests_snapshot echo 7
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 0
    mock state::get_tests_snapshot echo 7
    mock state::get_tests_skipped echo 0
    mock state::get_tests_passed echo 3

    console_results::render_result
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
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 0
    mock state::get_tests_snapshot echo 0
    mock state::get_tests_skipped echo 0
    mock state::get_tests_passed echo 3

    console_results::render_result
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
    console_results::render_result
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

  local test_name="a custom test"

  assert_matches \
    "✓ Passed.*$test_name.*(12 ms)" \
    "$(console_results::print_successful_test "$test_name" "12")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}

function test_print_successful_test_output_with_args() {
  local original_simple_output=$BASHUNIT_SIMPLE_OUTPUT
  export BASHUNIT_SIMPLE_OUTPUT=false

  local test_name="a custom test"
  local data="foo"

  assert_matches \
    "✓ Passed.*$test_name \($data\).*(12 ms)" \
    "$(console_results::print_successful_test "$test_name" "12" "$data")"

  export BASHUNIT_SIMPLE_OUTPUT=$original_simple_output
}
