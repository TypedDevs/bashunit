#!/usr/bin/env bash

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
  assert_same "" "$(helper::normalize_test_function_name)"
}

function test_normalize_test_function_name_one_word() {
  assert_same "Word" "$(helper::normalize_test_function_name "word")"
}

function test_normalize_test_function_name_snake_case() {
  assert_same "Some logic" "$(helper::normalize_test_function_name "test_some_logic")"
}

function test_normalize_double_test_function_name_snake_case() {
  assert_same "Test some logic" "$(helper::normalize_test_function_name "test_test_some_logic")"
}

function test_normalize_test_function_name_camel_case() {
  assert_same "SomeLogic" "$(helper::normalize_test_function_name "testSomeLogic")"
}

function test_get_functions_to_run_no_filter_should_return_all_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_same\
    "prefix_function1 prefix_function2 prefix_function3"\
    "$(helper::get_functions_to_run "prefix" "" "${functions[*]}")"
}

function test_get_functions_to_run_with_filter_should_return_matching_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_same "prefix_function1" "$(helper::get_functions_to_run "prefix" "function1" "${functions[*]}")"
}

function test_get_functions_to_run_filter_no_matching_functions_should_return_empty() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_same "" "$(helper::get_functions_to_run "prefix" "nonexistent" "${functions[*]}")"
}

function test_get_functions_to_run_fail_when_duplicates() {
  local functions=("prefix_function1" "prefix_function1")

  assert_general_error "$(helper::get_functions_to_run "prefix" "" "${functions[*]}")"
}

function test_dummy_function_is_executed_with_execute_function_if_exists() {
  local function_name='dummy_function'

  assert_same "dummy_function executed" "$(helper::execute_function_if_exists "$function_name")"
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
  file="$(current_dir)/fixtures/duplicate_functions.sh"

  assert_general_error "$(helper::check_duplicate_functions "$file")"
}

function test_check_duplicate_functions_without_duplicates() {
  local file
  file="$(current_dir)/fixtures/no_duplicate_functions.sh"

  assert_successful_code "$(helper::check_duplicate_functions "$file")"
}

function test_check_duplicate_functions_without_function_keyword() {
  local file
  file="$(current_dir)/fixtures/no_function_keyword_duplicates.sh"

  assert_general_error "$(helper::check_duplicate_functions "$file")"
}

function test_normalize_variable_name() {
  assert_same "valid_name123" "$(helper::normalize_variable_name "valid_name123")"
  assert_same "non_valid_symbols__________" "$(helper::normalize_variable_name "non_valid_symbols!@#$%^&*()")"
  assert_same "_123_starting_with_numbers" "$(helper::normalize_variable_name "123_starting_with_numbers")"
  assert_same "variable_name_with_spaces" "$(helper::normalize_variable_name "variable name with spaces")"
  assert_same "variable_name_with_hyphens" "$(helper::normalize_variable_name "variable-name-with-hyphens")"
  assert_same "_123_variable_name_" "$(helper::normalize_variable_name "123 variable-name!")"
  assert_same "_" "$(helper::normalize_variable_name "")"
  assert_same "variable_name_with_underscores" "$(helper::normalize_variable_name "variable_name_with_underscores")"
  assert_same "_variable" "$(helper::normalize_variable_name "_variable")"
  assert_same "__________" "$(helper::normalize_variable_name "!@#$%^&*()")"
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

  assert_same "data_provided" "$(helper::get_provider_data "fake_function_get_provider_data" "${BASH_SOURCE[0]}")"
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

  assert_same \
    "one two three" \
    "$(helper::get_provider_data "fake_function_get_provider_data_array" "${BASH_SOURCE[0]}")"
}

function test_get_provider_data_should_returns_empty_when_not_exists_provider_function() {
  # shellcheck disable=SC2317
  # data_provider not_existing_provider
  function fake_function_get_not_existing_provider_data() {
    return 0
  }

  assert_same "" "$(helper::get_provider_data "fake_function_get_not_existing_provider_data" "${BASH_SOURCE[0]}")"
}

function test_left_trim() {
  assert_same "foo" "$(helper::trim "       foo")"
}

function test_right_trim() {
  assert_same "foo" "$(helper::trim "foo       ")"
}

function test_trim() {
  assert_same "foo" "$(helper::trim "    foo   ")"
}

function test_find_files_recursive_given_file() {
  local path
  path="$(current_dir)/fixtures/tests/example1_test.sh"

  local result
  result=$(helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example1_test.sh" "$result"
}

function test_find_files_recursive_given_dir() {
  local path
  path="$(current_dir)/fixtures/tests"

  local result
  result=$(helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example1_test.sh
tests/unit/fixtures/tests/example2_test.sh"\
  "$result"
}

function test_find_files_recursive_given_wildcard() {
  local path
  path="$(current_dir)/fixtures/tests/*2_test.sh"

  local result
  result=$(helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example2_test.sh" "$result"
}

function test_get_latest_tag() {
  mock git<<EOF
fc9aac40eb8e5ad4483f08d79eb678a3650dcf78        refs/tags/0.1.0
a17e6816669ec8d0f18ed8c6d5564df9fc699bf9        refs/tags/0.10.0
3977be123b0b73cfdf4b4eff46b909f37aa83b3c        refs/tags/0.10.1
b546c693198870dd75d1a102b94f4ddad6f4f3ea        refs/tags/0.2.0
732ea5e8b16c3c05f0a6977b794ed7098e1839e2        refs/tags/0.3.0
EOF
  assert_same "0.10.1" "$(helpers::get_latest_tag)"
  unset -f git # remove the mock
}

function test_to_run_with_filter_matching_string_in_function_name() {
  local functions=("test_my_awesome_function" "test_your_awesome_function" "test_so_lala_function")

  assert_same\
    "test_your_awesome_function" "$(helper::get_functions_to_run "test" "test_your_awesome_function" "${functions[*]}")"

  assert_same\
    "test_my_awesome_function test_your_awesome_function"\
    "$(helper::get_functions_to_run "test" "awesome" "${functions[*]}")"
}

function test_interpolate_function_name() {
  local result
  result="$(helper::interpolate_function_name "test_name_::1::_foo" "bar")"
  assert_same "test_name_'bar'_foo" "$result"
}

function test_normalize_test_function_name_with_interpolation() {
  local fn="test_returns_value_::1::_given"
  export BASHUNIT_CURRENT_FUNCTION_NAME="$fn"
  # shellcheck disable=SC2155
  export BASHUNIT_INTERPOLATED_FUNCTION_NAME="$(helper::interpolate_function_name "$fn" "3")"
  assert_same "Returns value '3' given" "$(helper::normalize_test_function_name "$fn")"
}
