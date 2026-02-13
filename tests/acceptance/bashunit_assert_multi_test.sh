#!/usr/bin/env bash
set -euo pipefail

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

# Test multi-assertion mode
function test_multi_assert_exit_code_and_contains() {
  ./bashunit assert "echo 'some error' && exit 1" exit_code "1" contains "some error" 2>&1
  assert_successful_code
}

function test_multi_assert_exit_code_zero_and_output() {
  ./bashunit assert "echo 'success message'" exit_code "0" contains "success" 2>&1
  assert_successful_code
}

function test_multi_assert_multiple_output_assertions() {
  ./bashunit assert "echo 'hello world'" exit_code "0" contains "hello" contains "world" 2>&1
  assert_successful_code
}

function test_multi_assert_fails_on_exit_code_mismatch() {
  local exit_code
  ./bashunit assert "echo 'output' && exit 1" exit_code "0" 2>&1 && exit_code=$? || exit_code=$?
  assert_general_error "" "" "$exit_code"
}

function test_multi_assert_fails_on_contains_mismatch() {
  local exit_code
  ./bashunit assert "echo 'actual output'" exit_code "0" contains "expected" 2>&1 && exit_code=$? || exit_code=$?
  assert_general_error "" "" "$exit_code"
}

function test_multi_assert_missing_assertion_arg() {
  local exit_code
  local output
  output=$(./bashunit assert "echo test" exit_code 2>&1) && exit_code=$? || exit_code=$?
  assert_contains "Missing argument for assertion" "$output"
  assert_general_error "" "" "$exit_code"
}
