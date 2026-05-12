#!/usr/bin/env bash

function test_extract_assertion_runtime_output_keeps_user_output() {
  local runtime_output
  runtime_output=$'diagnostic from stderr\n✗ Failed: Example\n    Expected '\''1'\'''
  local rendered_assertion_output
  rendered_assertion_output=$'✗ Failed: Example\n    Expected '\''1'\'''

  local actual
  actual="$(bashunit::runner::extract_assertion_runtime_output "$runtime_output" "$rendered_assertion_output")"

  assert_same "diagnostic from stderr" "$actual"
}

function test_extract_assertion_runtime_output_ignores_bashunit_status_output_before_failure() {
  local runtime_output
  runtime_output=$'✒ Incomplete: Example    pending\n✗ Failed: Example\n    Expected '\''1'\'''
  local rendered_assertion_output
  rendered_assertion_output=$'✒ Incomplete: Example    pending\n✗ Failed: Example\n    Expected '\''1'\'''

  local actual
  actual="$(bashunit::runner::extract_assertion_runtime_output "$runtime_output" "$rendered_assertion_output")"

  assert_empty "$actual"
}

function test_extract_assertion_runtime_output_keeps_user_output_after_status_output() {
  local runtime_output
  runtime_output=$'✓ Passed: Previous assertion\ndiagnostic after pass\n✗ Failed: Example'
  local rendered_assertion_output
  rendered_assertion_output=$'✓ Passed: Previous assertion\n✗ Failed: Example'

  local actual
  actual="$(bashunit::runner::extract_assertion_runtime_output "$runtime_output" "$rendered_assertion_output")"

  assert_same "diagnostic after pass" "$actual"
}

function test_extract_assertion_runtime_output_keeps_user_output_that_looks_like_status_output() {
  local runtime_output
  runtime_output=$'✗ Failed: emitted by the code under test\n✗ Failed: Example'
  local rendered_assertion_output
  rendered_assertion_output="✗ Failed: Example"

  local actual
  actual="$(bashunit::runner::extract_assertion_runtime_output "$runtime_output" "$rendered_assertion_output")"

  assert_same "✗ Failed: emitted by the code under test" "$actual"
}

function test_detect_runtime_error_returns_empty_when_input_is_empty() {
  local actual
  actual="$(bashunit::runner::detect_runtime_error "")"

  assert_empty "$actual"
}

function test_detect_runtime_error_returns_empty_when_no_known_error() {
  local actual
  actual="$(bashunit::runner::detect_runtime_error "all good here")"

  assert_empty "$actual"
}

function test_detect_runtime_error_matches_command_not_found() {
  local actual
  actual="$(bashunit::runner::detect_runtime_error \
    "script.sh: line 3: foo: command not found")"

  assert_same "line 3: foo: command not found" "$actual"
}

function test_detect_runtime_error_matches_syntax_error() {
  local actual
  actual="$(bashunit::runner::detect_runtime_error \
    "bash: -c: line 1: syntax error near unexpected token")"

  assert_same "-c: line 1: syntax error near unexpected token" "$actual"
}

function test_detect_runtime_error_matches_killed() {
  local actual
  actual="$(bashunit::runner::detect_runtime_error "process: killed")"

  assert_same "killed" "$actual"
}

function test_detect_runtime_error_strips_newlines_from_extracted_message() {
  local input=$'bash: line 1: foo: command not found\nextra'
  local actual
  actual="$(bashunit::runner::detect_runtime_error "$input")"

  assert_same "line 1: foo: command not foundextra" "$actual"
}

function test_detect_runtime_error_matches_unexpected_eof() {
  local actual
  actual="$(bashunit::runner::detect_runtime_error \
    "bash: line 5: unexpected EOF while looking for matching")"

  assert_same "line 5: unexpected EOF while looking for matching" "$actual"
}
