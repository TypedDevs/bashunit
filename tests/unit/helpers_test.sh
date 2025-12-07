#!/usr/bin/env bash
# shellcheck disable=SC2317
# shellcheck disable=SC2329

function tear_down() {
  bashunit::helper::unset_if_exists fake_function
}

function tear_down_after_script() {
  bashunit::helper::unset_if_exists dummy_function
}

function dummy_function() {
  echo "dummy_function executed"
}

function test_normalize_test_function_name_empty() {
  assert_same "" "$(bashunit::helper::normalize_test_function_name)"
}

function test_normalize_test_function_name_one_word() {
  assert_same "Word" "$(bashunit::helper::normalize_test_function_name "word")"
}

function test_normalize_test_function_name_snake_case() {
  assert_same "Some logic" "$(bashunit::helper::normalize_test_function_name "test_some_logic")"
}

function test_normalize_double_test_function_name_snake_case() {
  assert_same "Test some logic" "$(bashunit::helper::normalize_test_function_name "test_test_some_logic")"
}

function test_normalize_test_function_name_camel_case() {
  assert_same "SomeLogic" "$(bashunit::helper::normalize_test_function_name "testSomeLogic")"
}

function test_normalize_test_function_name_custom_title() {
  bashunit::set_test_title "🔥 handles invalid input with 💣"
  local expected="🔥 handles invalid input with 💣"
  assert_same "$expected" \
    "$(bashunit::helper::normalize_test_function_name "test_handles_invalid_input")"
}

function test_normalize_test_function_name_uses_current_interpolated_name_from_state() {
  local fn_name="test_::1::_interpolated_output"
  local interpolated_fn="test_'value'_interpolated_output"

  bashunit::state::set_current_test_interpolated_function_name "$interpolated_fn"

  assert_same "'value' interpolated output" "$(bashunit::helper::normalize_test_function_name "$fn_name")"

  bashunit::state::reset_current_test_interpolated_function_name
}

function test_get_functions_to_run_no_filter_should_return_all_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_same\
    "prefix_function1 prefix_function2 prefix_function3"\
    "$(bashunit::helper::get_functions_to_run "prefix" "" "${functions[*]}")"
}

function test_get_functions_to_run_with_filter_should_return_matching_functions() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_same "prefix_function1" "$(bashunit::helper::get_functions_to_run "prefix" "function1" "${functions[*]}")"
}

function test_get_functions_to_run_filter_no_matching_functions_should_return_empty() {
  local functions=("prefix_function1" "prefix_function2" "other_function" "prefix_function3")

  assert_same "" "$(bashunit::helper::get_functions_to_run "prefix" "nonexistent" "${functions[*]}")"
}

function test_get_functions_to_run_fail_when_duplicates() {
  local functions=("prefix_function1" "prefix_function1")

  assert_general_error "$(bashunit::helper::get_functions_to_run "prefix" "" "${functions[*]}")"
}

function test_dummy_function_is_executed_with_execute_function_if_exists() {
  local function_name='dummy_function'

  assert_same "dummy_function executed" "$(bashunit::helper::execute_function_if_exists "$function_name")"
}

function test_no_function_is_executed_with_execute_function_if_exists() {
  local function_name='not_existing_function'

  assert_empty "$(bashunit::helper::execute_function_if_exists "$function_name")"
}

function test_successful_unset_if_exists_non_existent_function() {
  assert_successful_code "$(bashunit::helper::unset_if_exists "fake_function")"
}

function test_successful_unset_if_exists() {
  function fake_function() {
    return 0
  }

  assert_successful_code "$(bashunit::helper::unset_if_exists "fake_function")"
}

function test_check_duplicate_functions_with_duplicates() {
  local file
  file="$(bashunit::current_dir)/fixtures/duplicate_functions.sh"

  assert_general_error "$(bashunit::helper::check_duplicate_functions "$file")"
}

function test_check_duplicate_functions_without_duplicates() {
  local file
  file="$(bashunit::current_dir)/fixtures/no_duplicate_functions.sh"

  assert_successful_code "$(bashunit::helper::check_duplicate_functions "$file")"
}

function test_check_duplicate_functions_without_function_keyword() {
  local file
  file="$(bashunit::current_dir)/fixtures/no_function_keyword_duplicates.sh"

  assert_general_error "$(bashunit::helper::check_duplicate_functions "$file")"
}

function test_normalize_variable_name() {
  assert_same "valid_name123" "$(bashunit::helper::normalize_variable_name "valid_name123")"
  assert_same "non_valid_symbols__________" "$(bashunit::helper::normalize_variable_name "non_valid_symbols!@#$%^&*()")"
  assert_same "_123_starting_with_numbers" "$(bashunit::helper::normalize_variable_name "123_starting_with_numbers")"
  assert_same "variable_name_with_spaces" "$(bashunit::helper::normalize_variable_name "variable name with spaces")"
  assert_same "variable_name_with_hyphens" "$(bashunit::helper::normalize_variable_name "variable-name-with-hyphens")"
  assert_same "_123_variable_name_" \
    "$(bashunit::helper::normalize_variable_name "123 variable-name!")"
  assert_same "_" "$(bashunit::helper::normalize_variable_name "")"
  assert_same "variable_name_with_underscores" \
    "$(bashunit::helper::normalize_variable_name "variable_name_with_underscores")"
  assert_same "_variable" "$(bashunit::helper::normalize_variable_name "_variable")"
  assert_same "__________" "$(bashunit::helper::normalize_variable_name "!@#$%^&*()")"
}

function fake_provider_data_string() {
  echo "data_provided"
}

function test_get_provider_data() {
  # shellcheck disable=SC2317
  # @data_provider fake_provider_data_string
  function fake_function_get_provider_data() {
    return 0
  }

  assert_same "data_provided" \
    "$(bashunit::helper::get_provider_data "fake_function_get_provider_data" "${BASH_SOURCE[0]}")"
}

function fake_provider_data_array() {
  local data=("one" "two" "three")
  bashunit::data_set "${data[@]}"
}

function test_get_provider_data_array() {
  # @data_provider fake_provider_data_array
  # shellcheck disable=SC2317
  function fake_function_get_provider_data_array() {
    return 0
  }

  assert_same \
    "one two three ''" \
    "$(bashunit::helper::get_provider_data "fake_function_get_provider_data_array" "${BASH_SOURCE[0]}")"
}

function test_get_provider_data_should_returns_empty_when_not_exists_provider_function() {
  # shellcheck disable=SC2317
  # @data_provider not_existing_provider
  function fake_function_get_not_existing_provider_data() {
    return 0
  }

  assert_same "" \
    "$(bashunit::helper::get_provider_data "fake_function_get_not_existing_provider_data" "${BASH_SOURCE[0]}")"
}

function test_left_trim() {
  assert_same "foo" "$(bashunit::helper::trim "       foo")"
}

function test_right_trim() {
  assert_same "foo" "$(bashunit::helper::trim "foo       ")"
}

function test_trim() {
  assert_same "foo" "$(bashunit::helper::trim "    foo   ")"
}

function test_find_files_recursive_given_file() {
  local path
  path="$(bashunit::current_dir)/fixtures/tests/example1_test.sh"

  local result
  result=$(bashunit::helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example1_test.sh" "$result"
}

function test_find_files_recursive_given_dir() {
  local path
  path="$(bashunit::current_dir)/fixtures/tests"

  local result
  result=$(bashunit::helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example1_test.sh
tests/unit/fixtures/tests/example2_test.sh
tests/unit/fixtures/tests/example3_test.bash"\
  "$result"
}

function test_find_files_recursive_given_wildcard() {
  local path
  path="$(bashunit::current_dir)/fixtures/tests/*2_test.sh"

  local result
  result=$(bashunit::helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example2_test.sh" "$result"
}

function test_find_files_recursive_given_bash_extension() {
  local path
  path="$(bashunit::current_dir)/fixtures/tests/*3_test.bash"

  local result
  result=$(bashunit::helper::find_files_recursive "$path")

  assert_same "tests/unit/fixtures/tests/example3_test.bash" "$result"
}

function test_get_latest_tag() {
  bashunit::mock git<<EOF
fc9aac40eb8e5ad4483f08d79eb678a3650dcf78        refs/tags/0.1.0
a17e6816669ec8d0f18ed8c6d5564df9fc699bf9        refs/tags/0.10.0
3977be123b0b73cfdf4b4eff46b909f37aa83b3c        refs/tags/0.10.1
b546c693198870dd75d1a102b94f4ddad6f4f3ea        refs/tags/0.2.0
732ea5e8b16c3c05f0a6977b794ed7098e1839e2        refs/tags/0.3.0
EOF
  assert_same "0.10.1" "$(bashunit::helper::get_latest_tag)"
  unset -f git # remove the mock
}

function test_to_run_with_filter_matching_string_in_function_name() {
  local functions=("test_my_awesome_function" "test_your_awesome_function" "test_so_lala_function")

  assert_same "test_your_awesome_function" \
    "$(bashunit::helper::get_functions_to_run "test" "test_your_awesome_function" "${functions[*]}")"

  assert_same "test_my_awesome_function test_your_awesome_function" \
    "$(bashunit::helper::get_functions_to_run "test" "awesome" "${functions[*]}")"
}

function test_interpolate_fn_name() {
  local result
  result="$(bashunit::helper::interpolate_function_name "test_name_::1::_foo" "bar")"

  assert_same "test_name_'bar'_foo" "$result"
}

function test_normalize_test_function_name_with_interpolation() {
  local fn="test_returns_value_::1::_and_::2::_given"
  # shellcheck disable=SC2155
  local interpolated_fn="$(bashunit::helper::interpolate_function_name "$fn" "3" "4")"

  assert_same "Returns value '3' and '4' given" \
    "$(bashunit::helper::normalize_test_function_name "$fn" "$interpolated_fn")"
}

function helpers_test::find_total_in_subshell() {
  # "bashunit::helper::find_total_tests" needs the "data_set" function, so we have to source globals.sh first
  bash -c 'source src/globals.sh; source "$1"; shift; bashunit::helper::find_total_tests "$@"' \
    bash "$BASHUNIT_ROOT_DIR/src/helpers.sh" "$@"
}

function test_find_total_tests_no_files() {
  assert_same "0" "$(helpers_test::find_total_in_subshell)"
}

function test_find_total_tests_simple_file() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"

  assert_same "2" "$(helpers_test::find_total_in_subshell "" "$file")"
}

function test_find_total_tests_simple_file_bash() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.bash"

  assert_same "2" "$(helpers_test::find_total_in_subshell "" "$file")"
}

function test_find_total_tests_with_provider() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/provider_test.sh"

  assert_same "3" "$(helpers_test::find_total_in_subshell "" "$file")"
}

function test_find_total_tests_multiple_files() {
  local file1
  local file2
  file1="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"
  file2="$(bashunit::current_dir)/fixtures/find_total_tests/provider_test.sh"

  assert_same "5" "$(helpers_test::find_total_in_subshell "" "$file1" "$file2")"
}

function test_find_total_tests_with_filter() {
  local file1
  local file2
  file1="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"
  file2="$(bashunit::current_dir)/fixtures/find_total_tests/provider_test.sh"

  assert_same "3" "$(helpers_test::find_total_in_subshell "with_provider" "$file1" "$file2")"
}

function test_parse_file_path_filter_plain_path() {
  local result
  result=$(bashunit::helper::parse_file_path_filter "tests/unit/example_test.sh") || true

  local file_path filter
  {
    read -r file_path || true
    read -r filter || true
  } <<< "$result"

  assert_same "tests/unit/example_test.sh" "$file_path"
  assert_same "" "$filter"
}

function test_parse_file_path_filter_with_double_colon() {
  local result
  result=$(bashunit::helper::parse_file_path_filter "tests/unit/example_test.sh::test_my_function") || true

  local file_path filter
  {
    read -r file_path || true
    read -r filter || true
  } <<< "$result"

  assert_same "tests/unit/example_test.sh" "$file_path"
  assert_same "test_my_function" "$filter"
}

function test_parse_file_path_filter_with_line_number() {
  local result
  result=$(bashunit::helper::parse_file_path_filter "tests/unit/example_test.sh:42") || true

  local file_path filter
  {
    read -r file_path || true
    read -r filter || true
  } <<< "$result"

  assert_same "tests/unit/example_test.sh" "$file_path"
  assert_same "__line__:42" "$filter"
}

function test_parse_file_path_filter_with_colon_in_path() {
  local result
  result=$(bashunit::helper::parse_file_path_filter "/path/to:weird/example_test.sh::test_func") || true

  local file_path filter
  {
    read -r file_path || true
    read -r filter || true
  } <<< "$result"

  assert_same "/path/to:weird/example_test.sh" "$file_path"
  assert_same "test_func" "$filter"
}

function test_find_function_at_line_first_function() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"

  assert_same "test_first" "$(bashunit::helper::find_function_at_line "$file" 4)"
}

function test_find_function_at_line_second_function() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"

  assert_same "test_second" "$(bashunit::helper::find_function_at_line "$file" 8)"
}

function test_find_function_at_line_exact_function_line() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"

  assert_same "test_first" "$(bashunit::helper::find_function_at_line "$file" 3)"
}

function test_find_function_at_line_before_any_function() {
  local file
  file="$(bashunit::current_dir)/fixtures/find_total_tests/simple_test.sh"

  assert_same "" "$(bashunit::helper::find_function_at_line "$file" 1)"
}

function test_find_function_at_line_nonexistent_file() {
  local exit_code=0
  bashunit::helper::find_function_at_line "/nonexistent/file.sh" 10 2>/dev/null || exit_code=$?
  assert_same 1 "$exit_code"
}
