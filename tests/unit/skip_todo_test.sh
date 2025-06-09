#!/usr/bin/env bash

function test_skip_output() {
  assert_same\
    "$(console_results::print_skipped_test "Skip output")"\
    "$(skip)"
}

function test_skip_output_with_reason() {
  assert_same\
    "$(console_results::print_skipped_test "Skip output with reason" "Skipped because is skippable")"\
    "$(skip "Skipped because is skippable")"
}

function test_todo_output() {
  assert_same\
    "$(console_results::print_incomplete_test "Todo output")"\
    "$(todo)"
}

function test_todo_output_with_pending_details() {
  assert_same\
    "$(console_results::print_incomplete_test "Todo output with pending details" "Incomplete because pending details")"\
    "$(todo "Incomplete because pending details")"
}
