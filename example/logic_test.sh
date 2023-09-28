#!/bin/bash

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
SCRIPT="$ROOT_DIR/example/logic.sh"

function test_text_should_be_equal() {
  assert_equals "expected 123" "$($SCRIPT "123")"
}

function test_text_should_contain() {
  assert_contains "expect" "$($SCRIPT "123")"
}

function test_text_should_not_contain() {
  assert_not_contains "expecs" "$($SCRIPT "123")"
}

function test_text_should_match_a_regular_expression() {
  assert_matches ".*xpec*" "$($SCRIPT "123")"
}

function test_text_should_not_match_a_regular_expression() {
  assert_not_matches ".*xpes.*" "$($SCRIPT "123")"
}

function test_should_validate_an_ok_exit_code() {
  function fake_function() {
    return 0
  }

  fake_function

  assert_exit_code "0"
}


function test_should_validate_a_non_ok_exit_code() {
  function fake_function() {
    return 1
  }

  fake_function

  assert_exit_code "1"
}

function test_other_way_of_using_the_exit_code() {
  function fake_function() {
    return 1
  }

  assert_exit_code "1" "$(fake_function)"
}

function test_successful_exit_code() {
  function fake_function() {
    return 0
  }

  assert_successful_code "$(fake_function)"
}

function test_other_way_of_using_the_successful_exit_code() {
  function fake_function() {
    return 0
  }

  fake_function

  assert_successful_code
}

function test_general_error() {
  function fake_function() {
    return 1
  }

  assert_general_error "$(fake_function)"
}

function test_other_way_of_using_the_general_error() {
  function fake_function() {
    return 1
  }

  fake_function

  assert_general_error
}

function test_should_assert_exit_code_of_a_non_existing_command() {
  assert_command_not_found "$(a_non_existing_function > /dev/null 2>&1)"
}

function test_should_assert_that_an_array_contains_1234() {
  local distros=(Ubuntu 1234 Linux\ Mint)

  assert_array_contains "1234" "${distros[@]}"
}

function test_should_assert_that_an_array_not_contains_1234() {
  local distros=(Ubuntu 1234 Linux\ Mint)

  assert_array_not_contains "a_non_existing_element" "${distros[@]}"
}
