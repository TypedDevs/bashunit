#!/usr/bin/env bash

# Custom assertion that uses fail internally
function _assert_valid_json() {
  local json="$1"

  if ! echo "$json" | jq . >/dev/null 2>&1; then
    bashunit::fail "Invalid json: $json"
    return
  fi

  bashunit::state::add_assertions_passed
}

# Custom assertion that uses bashunit::assertion_failed
function _assert_positive_number() {
  local number="$1"

  if ! [[ "$number" =~ ^[0-9]+$ ]] || [[ "$number" -le 0 ]]; then
    bashunit::assertion_failed "positive number" "$number"
    return
  fi

  bashunit::assertion_passed
}

# Custom assertion that uses assert_same internally
function _assert_length_equals() {
  local expected_length="$1"
  local string="$2"
  local actual_length=${#string}

  assert_same "$expected_length" "$actual_length"
}

# Tests

function test_custom_assertion_with_fail_shows_correct_test_name() {
  # This test verifies that when a custom assertion uses fail(),
  # the failure message shows the test function name, not the custom assertion name
  local output
  output="$(
    # Temporarily override bashunit::state::print_line to capture output
    _captured_output=""
    # shellcheck disable=SC2317,SC2329
    bashunit::state::print_line() {
      _captured_output="$2"
      echo "$_captured_output"
    }

    # Force a failure using our custom assertion with invalid JSON
    _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
    _assert_valid_json "invalid json"

    echo "$_captured_output"
  )"

  # The output should contain the test function name (normalized from the test function)
  assert_contains "Custom assertion with fail shows correct test name" "$output"
  assert_not_contains "Assert valid json" "$output"
}

function test_custom_assertion_with_bashunit_assertion_failed_shows_correct_test_name() {
  # This test verifies that when a custom assertion uses bashunit::assertion_failed(),
  # the failure message shows the test function name, not the custom assertion name
  local output
  output="$(
    _captured_output=""
    # shellcheck disable=SC2317,SC2329
    bashunit::state::print_line() {
      _captured_output="$2"
      echo "$_captured_output"
    }

    _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
    _assert_positive_number "-5"

    echo "$_captured_output"
  )"

  assert_contains \
    "Custom assertion with bashunit assertion failed shows correct test name" "$output"
  assert_not_contains "Assert positive number" "$output"
}

function test_custom_assertion_calling_assert_same_shows_correct_test_name() {
  # This test verifies that when a custom assertion calls another assertion like assert_same,
  # the failure message shows the test function name, not the intermediate assertion name
  local output
  output="$(
    _captured_output=""
    # shellcheck disable=SC2317,SC2329
    bashunit::state::print_line() {
      _captured_output="$2"
      echo "$_captured_output"
    }

    _BASHUNIT_ASSERTION_FAILED_IN_TEST=0
    _assert_length_equals "5" "abc" # length is 3, not 5

    echo "$_captured_output"
  )"

  assert_contains "Custom assertion calling assert same shows correct test name" "$output"
  assert_not_contains "Assert length equals" "$output"
  assert_not_contains "Assert same" "$output"
}

function test_helper_find_test_function_name_finds_test() {
  # Test that bashunit::helper::find_test_function_name correctly finds the test function
  local found_name
  found_name="$(bashunit::helper::find_test_function_name)"

  assert_same "test_helper_find_test_function_name_finds_test" "$found_name"
}

function test_helper_find_test_function_name_from_nested_function() {
  # Test that bashunit::helper::find_test_function_name works from nested functions
  _inner_function() {
    bashunit::helper::find_test_function_name
  }

  local found_name
  found_name="$(_inner_function)"

  assert_same "test_helper_find_test_function_name_from_nested_function" "$found_name"
}

function test_helper_find_test_function_name_from_deeply_nested() {
  # Test from deeply nested functions
  _level3() {
    bashunit::helper::find_test_function_name
  }

  _level2() {
    _level3
  }

  _level1() {
    _level2
  }

  local found_name
  found_name="$(_level1)"

  assert_same "test_helper_find_test_function_name_from_deeply_nested" "$found_name"
}
