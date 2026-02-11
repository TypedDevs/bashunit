#!/usr/bin/env bash

function test_skip_output() {
  assert_same "$(bashunit::console_results::print_skipped_test "Skip output")" \
    "$(bashunit::skip)"
}

function test_skip_output_with_reason() {
  assert_same "$(bashunit::console_results::print_skipped_test "Skip output with reason" "Skipped because is skippable")" \
    "$(bashunit::skip "Skipped because is skippable")"
}

function test_todo_output() {
  assert_same "$(bashunit::console_results::print_incomplete_test "Todo output")" \
    "$(bashunit::todo)"
}

function test_todo_output_with_pending_details() {
  local expected
  expected="$(bashunit::console_results::print_incomplete_test \
    "Todo output with pending details" "Incomplete because pending details")"
  assert_same "$expected" "$(bashunit::todo "Incomplete because pending details")"
}
