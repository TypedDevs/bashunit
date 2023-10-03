#!/bin/bash

function tear_down() {
  helper::unset_if_exists fake_function
}

function tear_down_after_script() {
  helper::unset_if_exists dummy_function
}

function dummy_function() {
  echo "dummy_function executed"
}

function test_normalize_test_function_name_empty() {
  assert_equals "" "$(helper::normalize_test_function_name)"
}

function test_normalize_test_function_name_one_word() {
  assert_equals "Word" "$(helper::normalize_test_function_name "word")"
}

function test_normalize_test_function_name_snake_case() {
  assert_equals "Some logic" "$(helper::normalize_test_function_name "test_some_logic")"
}

function test_normalize_test_function_name_camel_case() {
  assert_equals "SomeLogic" "$(helper::normalize_test_function_name "testSomeLogic")"
}

function test_get_functions_to_run_no_filter_should_return_all_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_equals\
    "prefix_function1 prefix_function2 prefix_function3"\
    "$(helper::get_functions_to_run "prefix" "" "${functions[*]}")"
}

function test_get_functions_to_run_with_filter_should_return_matching_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_equals "prefix_function1" "$(helper::get_functions_to_run "prefix" "function1" "${functions[*]}")"
}

function test_get_functions_to_run_filter_no_matching_functions_should_return_empty() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_equals "" "$(helper::get_functions_to_run "prefix" "nonexistent" "${functions[*]}")"
}

function test_get_functions_to_run_fail_when_duplicates() {
  local functions=("prefix_function1" "prefix_function1")

  assert_general_error "$(helper::get_functions_to_run "prefix" "" "${functions[*]}")"
}

function test_dummy_function_is_executed_with_execute_function_if_exists() {
  local function_name='dummy_function'

  assert_equals "dummy_function executed" "$(helper::execute_function_if_exists "$function_name")"
}

function test_no_function_is_executed_with_execute_function_if_exists() {
  local function_name='not_existing_function'

  assert_empty "$(helper::execute_function_if_exists "$function_name")"
}

function test_successful_unset_if_exists_non_existent_function() {
  assert_successful_code "$(helper::unset_if_exists "fake_function")"
}

function test_successful_unset_if_exists() {
  # shellcheck disable=SC2317
  function fake_function() {
    return 0
  }

  assert_successful_code "$(helper::unset_if_exists "fake_function")"
}

function test_check_duplicate_functions_with_duplicates() {
  local file
  file="$(dirname "${BASH_SOURCE[0]}")/fixtures/duplicate_functions.sh"

  assert_general_error "$(helper::check_duplicate_functions "$file")"
}

function test_check_duplicate_functions_without_duplicates() {
  local file
  file="$(dirname "${BASH_SOURCE[0]}")/fixtures/no_duplicate_functions.sh"

  assert_successful_code "$(helper::check_duplicate_functions "$file")"
}
