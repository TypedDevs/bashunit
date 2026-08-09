#!/usr/bin/env bash

# @data_provider provide_core_assertions_requiring_arguments
function test_core_assertions_reject_missing_arguments() {
  local assertion=$1
  local required=$2
  local signature=$3
  local output exit_code=0

  if [ "$required" -eq 1 ]; then
    output=$("$assertion" 2>&1) || exit_code=$?
  elif [ "$required" -eq 3 ]; then
    output=$("$assertion" "first" "second" 2>&1) || exit_code=$?
  else
    output=$("$assertion" "first" 2>&1) || exit_code=$?
  fi

  assert_same 2 "$exit_code"
  assert_same \
    "bashunit: assertion usage error: $assertion expects $required arguments ($signature), got $((required - 1))" \
    "$output"
}

function provide_core_assertions_requiring_arguments() {
  bashunit::data_set assert_same 2 "expected, actual"
  bashunit::data_set assert_equals 2 "expected, actual"
  bashunit::data_set assert_not_same 2 "expected, actual"
  bashunit::data_set assert_not_equals 2 "expected, actual"
  bashunit::data_set assert_contains 2 "expected, actual"
  bashunit::data_set assert_contains_ignore_case 2 "expected, actual"
  bashunit::data_set assert_not_contains 2 "expected, actual"
  bashunit::data_set assert_matches 2 "pattern, actual"
  bashunit::data_set assert_not_matches 2 "pattern, actual"
  bashunit::data_set assert_string_starts_with 2 "expected, actual"
  bashunit::data_set assert_string_not_starts_with 2 "expected, actual"
  bashunit::data_set assert_string_ends_with 2 "expected, actual"
  bashunit::data_set assert_string_not_ends_with 2 "expected, actual"
  bashunit::data_set assert_less_than 2 "expected, actual"
  bashunit::data_set assert_less_or_equal_than 2 "expected, actual"
  bashunit::data_set assert_greater_than 2 "expected, actual"
  bashunit::data_set assert_greater_or_equal_than 2 "expected, actual"
  bashunit::data_set assert_within_delta 3 "expected, actual, delta"
  bashunit::data_set assert_line_count 2 "expected, actual"
  bashunit::data_set assert_string_matches_format 2 "format, actual"
  bashunit::data_set assert_string_not_matches_format 2 "format, actual"
  bashunit::data_set assert_command_available 1 "command"
}

function test_empty_values_still_count_as_supplied_arguments() {
  assert_same "" ""
  assert_equals "" ""
  assert_contains "" ""
}
