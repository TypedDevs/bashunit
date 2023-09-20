#!/bin/bash

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
SCRIPT="$ROOT_DIR/example/logic.sh"

function test_text_should_be_equal() {
  assertEquals "expected 123" "$($SCRIPT "123")"
}

function test_text_should_contain() {
  assertContains "expect" "$($SCRIPT "123")"
}

function test_text_should_not_contain() {
  assertNotContains "expecs" "$($SCRIPT "123")"
}

function test_text_should_match_a_regular_expression() {
  assertMatches ".*xpec*" "$($SCRIPT "123")"
}

function test_text_should_not_match_a_regular_expression() {
  assertNotMatches ".*xpes.*" "$($SCRIPT "123")"
}

function test_should_validate_an_ok_exit_code() {
  function fake_function() {
    return 0
  }

  fake_function

  assertExitCode "0"
}


function test_should_validate_a_non_ok_exit_code() {
  function fake_function() {
    return 1
  }

  fake_function

  assertExitCode "1"
}

function test_other_way_of_using_the_exit_code() {
  function fake_function() {
    return 1
  }

  assertExitCode "1" "$(fake_function)"
}

function test_successful_exit_code() {
  function fake_function() {
    return 0
  }

  assertSuccessfulCode "$(fake_function)"
}

function test_other_way_of_using_the_successful_exit_code() {
  function fake_function() {
    return 0
  }

  fake_function

  assertSuccessfulCode
}

function test_general_error() {
  function fake_function() {
    return 1
  }

  assertGeneralError "$(fake_function)"
}

function test_other_way_of_using_the_general_error() {
  function fake_function() {
    return 1
  }

  fake_function

  assertGeneralError
}

function test_should_assert_exit_code_of_a_non_existing_command() {
  assertCommandNotFound "$(a_non_existing_function > /dev/null 2>&1)"
}

function test_should_assert_that_an_array_contains_1234() {
  local distros=(Ubuntu 1234 Linux\ Mint)

  assertArrayContains "1234" "${distros[@]}"
}

function test_should_assert_that_an_array_not_contains_1234() {
  local distros=(Ubuntu 1234 Linux\ Mint)

  assertArrayNotContains "a_non_existing_element" "${distros[@]}"
}
