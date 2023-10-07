#!/bin/bash

function mock_all_state_getters() {
  mock state::is_duplicated_test_functions_found echo false
  mock state::get_tests_passed echo 0
  mock state::get_tests_failed echo 0
  mock state::get_tests_skipped echo 0
  mock state::get_tests_incomplete echo 0
  mock state::get_assertions_passed echo 0
  mock state::get_assertions_failed echo 0
  mock state::get_assertions_skipped echo 0
  mock state::get_assertions_incomplete echo 0
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

function test_total_tests_is_the_sum_of_passed_skipped_incomplete_and_failed_tests() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_tests_passed echo 4
    mock state::get_tests_skipped echo 5
    mock state::get_tests_incomplete echo 7
    mock state::get_tests_failed echo 2

    console_results::render_result
  )

  assert_matches "Tests:.*18 total.*Assertions:.*0 total" "$render_result"
}

function test_total_asserts_is_the_sum_of_passed_skipped_incomplete_and_failed_asserts() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::get_assertions_passed echo 4
    mock state::get_assertions_skipped echo 5
    mock state::get_assertions_incomplete echo 7
    mock state::get_assertions_failed echo 2

    console_results::render_result
  )

  assert_matches "Tests:.*0 total.*Assertions:.*18 total" "$render_result"
}

function test_render_execution_time() {
  if [[ $_OS == "OSX" ]]; then
    skip "Skipping in OSX"
    return
  fi

  assert_matches "Time taken: [[:digit:]]+ ms" "$(console_results::render_result)"
}

function test_not_render_execution_time_on_osx() {
  local render_result
  render_result=$(
    _OS='OSX'

    console_results::render_result
  )

  assert_not_matches "Time taken: [[:digit:]]+ ms" "$render_result"
}

function test_only_render_error_result_when_some_duplicated_fails() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::is_duplicated_test_functions_found echo true
    mock state::get_tests_failed echo 1
    mock state::get_tests_incomplete echo 4
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
  )

  assert_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
}

function test_only_render_error_result_when_some_test_fails() {
  set +e

  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 1
    mock state::get_tests_incomplete echo 4
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
}

function test_only_render_incomplete_result_when_no_test_fails_and_some_incomplete() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 4
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
}

function test_only_render_skipped_result_when_no_test_fails_nor_incomplete_and_some_skipped() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 0
    mock state::get_tests_skipped echo 2
    mock state::get_tests_passed echo 3

    console_results::render_result
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_contains "Some tests skipped" "$render_result"
  assert_not_contains "All tests passed" "$render_result"
}

function test_only_render_success_result_when_all_tests_passes() {
  local render_result
  render_result=$(
    mock_all_state_getters
    mock state::is_duplicated_test_functions_found echo false
    mock state::get_tests_failed echo 0
    mock state::get_tests_incomplete echo 0
    mock state::get_tests_skipped echo 0
    mock state::get_tests_passed echo 3

    console_results::render_result
  )

  assert_not_contains "Duplicate test functions found" "$render_result"
  assert_not_contains "Some tests failed" "$render_result"
  assert_not_contains "Some tests incomplete" "$render_result"
  assert_not_contains "Some tests skipped" "$render_result"
  assert_contains "All tests passed" "$render_result"
}
