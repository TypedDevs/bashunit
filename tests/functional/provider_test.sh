#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  _GLOBAL="aa-bb"
}

# @data_provider provide_multiples_values
function test_multiple_values_from_data_provider() {
  local first=$1
  local second=$2

  assert_equals "${_GLOBAL}" "$first-$second"
}

function provide_multiples_values() {
  echo "aa" "bb"
}

# @data_provider provide_single_values
function test_single_values_from_data_provider() {
  local data="$1"

  assert_not_equals "zero" "$data"
}

function provide_single_values() {
  echo "one"
  echo "two"
  echo "three"
}

# @data_provider provide_single_value
function test_single_value_from_data_provider() {
  local current_data="$1"

  assert_same "one" "$current_data"
}

function provide_single_value() {
  echo "one"
}

# @data_provider provide_empty_value
function test_empty_value_from_data_provider() {
  local first="$1"
  local second="$2"

  assert_same "" "$first"
  assert_same "two" "$second"
}

function provide_empty_value() {
  data_set "" "two"
}

# @data_provider provide_long_value
function test_long_value_from_data_provider() {
  local value="$1"
  assert_same "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz" "$value"
}

function provide_long_value() {
  data_set "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
}

# @data_provider provide_value_with_tabs
function test_value_with_tabs_from_data_provider() {
  local value="$1"

  assert_same "value	with	tabs" "$value"
}

function provide_value_with_tabs() {
  data_set "value	with	tabs"
}

# @data_provider provide_value_with_newline
function test_value_with_newline_from_data_provider() {
  local value="$1"

  assert_same "value
with
newline" "$value"
}

function provide_value_with_newline() {
  data_set "value
with
newline"
}

# @data_provider provide_value_with_whitespace
function test_value_with_whitespace_from_data_provider() {
  local first="$1"
  local second="$2"

  assert_same "first value" "$first"
  assert_same "second value" "$second"
}

function provide_value_with_whitespace() {
  data_set "first value" "second value"
}

# @data_provider provide_value_with_trailing_whitespace
function test_trailing_whitespace_in_last_value_from_data_provider() {
  local expected="$1"
  local actual="$2"

  assert_same "${expected}" "${actual}"
}

function provide_value_with_trailing_whitespace() {
  # Each data_set is passed the same value twice (expected, actual) to verify preservation
  data_set "value " "value "
  data_set "value    " "value    "
}

# @data_provider provide_eval_gotchas
function test_eval_gotchas_from_data_provider() {
  input=$1
  expected=$2
  assert_equals "${input}" "${expected}"
}

function provide_eval_gotchas() {
  echo "*" "*"
  echo "|" "|"
  echo "&" "&"
  echo ";" ";"
  echo "1;2" "1;2"
}

# @data_provider provide_single_arg_with_space
function test_single_arg_with_space_from_data_provider() {
  assert_same 1 $#
  assert_same "test     test" "$1"
}

function provide_single_arg_with_space() {
  data_set "test     test"
}

# @data_provider provide_two_args_with_spaces
function test_two_args_with_spaces_from_data_provider() {
  assert_same 2 $#
  assert_same "first test" "$1"
  assert_same "second test" "$2"
}

function provide_two_args_with_spaces() {
  data_set "first test" "second test"
}
