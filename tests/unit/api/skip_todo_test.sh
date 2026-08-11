#!/usr/bin/env bash

function test_skip_output() {
  assert_same "$(bashunit::console_results::print_skipped_test "Skip output")" \
    "$(bashunit::skip)"
}

function test_skip_output_with_reason() {
  assert_same \
    "$(bashunit::console_results::print_skipped_test "Skip output with reason" "Skipped because is skippable")" \
    "$(bashunit::skip "Skipped because is skippable")"
}

# Only the paths that do NOT skip can be asserted from a test: skipping ends
# the calling test on purpose, so those are covered in
# tests/acceptance/bashunit_conditional_skip_test.sh.
function test_skip_if_a_false_condition_leaves_the_test_running() {
  bashunit::skip_if false "never used"

  assert_same "reached" "reached"
}

function test_skip_if_evaluates_the_condition_as_a_shell_command() {
  bashunit::skip_if "[ 1 -eq 2 ]" "never used"

  assert_same "reached" "reached"
}

function test_skip_unless_a_true_condition_leaves_the_test_running() {
  bashunit::skip_unless true "never used"

  assert_same "reached" "reached"
}

function test_skip_unless_command_accepts_several_present_commands() {
  bashunit::skip_unless_command bash command

  assert_same "reached" "reached"
}

function test_skip_on_an_unknown_os_reports_a_usage_error() {
  local output
  local ec=0

  output=$(bashunit::skip_on "plan9" "reason" 2>&1) || ec=$?

  assert_equals "1" "$ec"
  assert_contains "bashunit::skip_on accepts windows, macos or linux, got 'plan9'" "$output"
}

function test_skip_on_another_os_leaves_the_test_running() {
  local other="windows"
  if bashunit::check_os::is_windows; then
    other="linux"
  fi

  bashunit::skip_on "$other" "never used"

  assert_same "reached" "reached"
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
