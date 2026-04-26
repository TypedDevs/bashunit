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
