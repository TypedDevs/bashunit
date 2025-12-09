#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(bashunit::current_dir)"

SCRIPT="$ROOT_DIR/logic.sh"

function test_text_should_be_equal() {
  assert_same "expected 123" "$($SCRIPT "123")"
}

function test_text_should_contain() {
  assert_contains "expect" "$($SCRIPT "123")"
}

function test_text_should_not_contain() {
  assert_not_contains "expecs" "$($SCRIPT "123")"
}

function test_text_should_match_a_regular_expression() {
  assert_not_contains ".*xpec*" "$($SCRIPT "123")"
}

function test_text_should_not_match_a_regular_expression() {
  assert_not_contains ".*xpes*" "$($SCRIPT "123")"
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

  set +e

  fake_function

  assert_exit_code "1"
}

function test_other_way_of_using_the_exit_code() {
  function fake_function() {
    return 1
  }

  assert_exit_code "1" "$(fake_function)"
}
