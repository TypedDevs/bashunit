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

function test_read_and_store_files_recursive() {
  local path="tests"
  local expected_files_count
  local result

  expected_files_count="$(find "$path" -type f -name '*[tT]est.sh' -type f | wc -l)"
  result=$(helper::read_and_store_files_recursive "$path")
  IFS=' ' read -r -a result <<< "$result"

  assert_equals "$(helper::trim "$expected_files_count")" "${#result[@]}"
}

function test_normalize_variable_name() {
  assert_equals "valid_name123" "$(helper::normalize_variable_name "valid_name123")"
  assert_equals "non_valid_symbols__________" "$(helper::normalize_variable_name "non_valid_symbols!@#$%^&*()")"
  assert_equals "_123_starting_with_numbers" "$(helper::normalize_variable_name "123_starting_with_numbers")"
  assert_equals "variable_name_with_spaces" "$(helper::normalize_variable_name "variable name with spaces")"
  assert_equals "variable_name_with_hyphens" "$(helper::normalize_variable_name "variable-name-with-hyphens")"
  assert_equals "_123_variable_name_" "$(helper::normalize_variable_name "123 variable-name!")"
  assert_equals "_" "$(helper::normalize_variable_name "")"
  assert_equals "variable_name_with_underscores" "$(helper::normalize_variable_name "variable_name_with_underscores")"
  assert_equals "_variable" "$(helper::normalize_variable_name "_variable")"
  assert_equals "__________" "$(helper::normalize_variable_name "!@#$%^&*()")"
}

function fake_provider_data_string() {
  echo "data_provided"
}

function test_get_provider_data() {
  # shellcheck disable=SC2317
  # data_provider fake_provider_data_string
  function fake_function_get_provider_data() {
    return 0
  }

  assert_equals "data_provided" "$(helper::get_provider_data "fake_function_get_provider_data" "${BASH_SOURCE[0]}")"
}

function fake_provider_data_array() {
  local data=("one" "two" "three")
  echo "${data[@]}"
}

function test_get_provider_data_array() {
  # shellcheck disable=SC2317
  # data_provider fake_provider_data_array
  function fake_function_get_provider_data_array() {
    return 0
  }

  assert_equals \
    "one two three" \
    "$(helper::get_provider_data "fake_function_get_provider_data_array" "${BASH_SOURCE[0]}")"
}

function test_get_provider_data_should_returns_empty_when_not_exists_provider_function() {
  # shellcheck disable=SC2317
  # data_provider not_existing_provider
  function fake_function_get_not_existing_provider_data() {
    return 0
  }

  assert_equals "" "$(helper::get_provider_data "fake_function_get_not_existing_provider_data" "${BASH_SOURCE[0]}")"
}

function test_left_trim() {
  assert_equals "foo" "$(helper::trim "       foo")"
}

function test_right_trim() {
  assert_equals "foo" "$(helper::trim "foo       ")"
}

function test_trim() {
  assert_equals "foo" "$(helper::trim "    foo   ")"
}
