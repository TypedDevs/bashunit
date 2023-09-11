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
