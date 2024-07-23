#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_MULTILINE_STR="first line
  \n
four line
find me with \n a regular expression"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_direct_fn_call_passes() {
  local expected="foo"
  local actual="foo"

  ./bashunit -a assert_equals --env "$TEST_ENV_FILE" "$expected" $actual
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

  assert_match_snapshot "$(./bashunit -a assert_equals --env "$TEST_ENV_FILE" "$expected" $actual)"
  assert_general_error "$(./bashunit -a assert_equals --env "$TEST_ENV_FILE" "$expected" $actual)"
}

function test_bashunit_direct_fn_call_non_existing_fn() {
  assert_match_snapshot "$(./bashunit -a non_existing_fn --env "$TEST_ENV_FILE")"
  assert_command_not_found "$(./bashunit -a non_existing_fn --env "$TEST_ENV_FILE")"
}
