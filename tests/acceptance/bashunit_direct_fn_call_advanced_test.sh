#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

function test_bashunit_direct_fn_call_failure() {
  local expected="foo"
  local actual="bar"

  assert_match_snapshot \
    "$(./bashunit --no-parallel -a assert_same --env "$TEST_ENV_FILE" "$expected" $actual 2>&1)"
  assert_general_error \
    "$(./bashunit --no-parallel -a assert_same --env "$TEST_ENV_FILE" "$expected" $actual)"
}

function test_bashunit_direct_fn_call_non_existing_fn() {
  assert_match_snapshot "$(./bashunit --no-parallel -a non_existing_fn --env "$TEST_ENV_FILE" 2>&1)"
  assert_command_not_found "$(./bashunit --no-parallel -a non_existing_fn --env "$TEST_ENV_FILE")"
}

# shellcheck disable=SC2155
function test_bashunit_assert_exit_code_successful_with_inner_func() {
  local temp=$(mktemp)
  # shellcheck disable=SC2116
  local output="$(./bashunit --no-parallel -a exit_code "0" "$(echo "unknown command")" 2>"$temp")"

  assert_empty "$output"
  assert_file_contains "$temp" "Command not found: unknown command"
}

# shellcheck disable=SC2155
function test_bashunit_assert_exit_code_error_with_inner_func() {
  local temp=$(mktemp)
  local no_color_flag=""
  bashunit::env::is_no_color_enabled && no_color_flag="--no-color"
  # shellcheck disable=SC2116,SC2086
  local output="$(./bashunit --no-parallel $no_color_flag -a exit_code "1" "$(echo "unknown command")" 2>"$temp")"

  assert_empty "$output"

  assert_file_contains "$temp" \
    "$(bashunit::console_results::print_failed_test "assert exit_code" "0" "to be" "1")"
}

function test_bashunit_assert_exit_code_str_successful_code() {
  ./bashunit -a exit_code "0" "./bashunit -a same 1 1"
  assert_successful_code
}

function test_bashunit_assert_exit_code_str_general_error() {
  ./bashunit -a exit_code "1" "./bashunit -a same 1 2"
  assert_successful_code
}

# shellcheck disable=SC2155
function test_bashunit_assert_exit_code_str_successful_but_exit_code_error() {
  local temp=$(mktemp)
  local no_color_flag=""
  bashunit::env::is_no_color_enabled && no_color_flag="--no-color"
  # shellcheck disable=SC2086
  local output="$(./bashunit --no-parallel $no_color_flag -a exit_code "1" "echo something to stdout" 2>"$temp")"

  assert_same "something to stdout" "$output"

  assert_file_contains "$temp" \
    "$(bashunit::console_results::print_failed_test "assert exit_code" "1" "but got " "0")"
}

# shellcheck disable=SC2155
function test_bashunit_assert_exit_code_str_successful_and_exit_code_ok() {
  local temp=$(mktemp)
  local output="$(./bashunit --no-parallel -a exit_code "0" "echo something to stdout" 2>"$temp")"

  assert_same "something to stdout" "$output"
  assert_empty "$(cat "$temp")"
}
