#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_MULTILINE_STR="first line
  \n
four line
find me with \n a regular expression"
}

function test_bashunit_direct_fn_call_passes() {
  local expected="foo"
  local actual="foo"

  ./bashunit -a assert_same --env "$TEST_ENV_FILE" "$expected" $actual
  assert_successful_code
}

function test_bashunit_direct_fn_call_without_assert_prefix_passes() {
  local expected="foo"
  local actual="foo"

  ./bashunit -a equals --env "$TEST_ENV_FILE" "$expected" $actual
  assert_successful_code
}

function test_bashunit_assert_line_count() {
  ./bashunit -a line_count 6 "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_contains() {
  ./bashunit -a contains "four" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_not_contains() {
  ./bashunit -a not_contains "unknown" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_matches() {
  ./bashunit -a matches "with.+regular expr" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_not_matches() {
  ./bashunit -a not_matches "unknown" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_string_starts_with() {
  ./bashunit -a string_starts_with "first" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_string_not_starts_with() {
  ./bashunit -a string_not_starts_with "unknown" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_string_ends_with() {
  ./bashunit -a string_ends_with "expression" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_assert_string_not_ends_with() {
  ./bashunit -a string_not_ends_with "unknown" "$TEST_MULTILINE_STR"
  assert_successful_code
}

function test_bashunit_direct_fn_call_failure() {
  local expected="foo"
  local actual="bar"

  assert_match_snapshot "$(./bashunit -a assert_same --env "$TEST_ENV_FILE" "$expected" $actual 2>&1)"
  assert_general_error "$(./bashunit -a assert_same --env "$TEST_ENV_FILE" "$expected" $actual)"
}

function test_bashunit_direct_fn_call_non_existing_fn() {
  assert_match_snapshot "$(./bashunit -a non_existing_fn --env "$TEST_ENV_FILE" 2>&1)"
  assert_command_not_found "$(./bashunit -a non_existing_fn --env "$TEST_ENV_FILE")"
}

function test_bashunit_assert_exit_code_successful_with_inner_func() {
  local temp
  temp=$(mktemp)

  local output
  # shellcheck disable=SC2116
  output="$(./bashunit -a exit_code "0" "$(echo "this wont go to stdout")" 2> "$temp")"

  assert_empty "$output"
  assert_empty "$(cat "$temp")"

  rm "$temp"
}

function test_bashunit_assert_exit_code_error_with_inner_func() {
  local temp
  temp=$(mktemp)

  local output
  # shellcheck disable=SC2116
  output="$(./bashunit -a exit_code "1" "$(echo "this wont go to stdout")" 2> "$temp")"

  assert_empty "$output"

  assert_contains\
    "$(console_results::print_failed_test "Main::exec assert" "0" "to be" "1")"\
    "$(cat "$temp")"

  rm "$temp"
}

function test_bashunit_assert_exit_code_eval_successful_code() {
  ./bashunit -a exit_code "0" "eval ./bashunit -a same 1 1"
  assert_successful_code
}

function test_bashunit_assert_exit_code_eval_general_error() {
  ./bashunit -a exit_code "1" "eval ./bashunit -a same 0 1"
  assert_successful_code
}

function test_bashunit_assert_exit_code_eval_successful_but_exit_code_error() {
  local temp
  temp=$(mktemp)

  local output
  output="$(./bashunit -a exit_code "1" "eval echo something to stdout" 2> "$temp")"

  assert_same "something to stdout" "$output"

  assert_contains\
    "$(console_results::print_failed_test "Main::exec assert" "1" "but got " "0")"\
    "$(cat "$temp")"

  rm "$temp"
}

function test_bashunit_assert_exit_code_eval_successful_and_exit_code_ok() {
  local temp
  temp=$(mktemp)

  local output
  output="$(./bashunit -a exit_code "0" "eval echo something to stdout" 2> "$temp")"

  assert_same "something to stdout" "$output"
  assert_empty "$(cat "$temp")"

  rm "$temp"
}
