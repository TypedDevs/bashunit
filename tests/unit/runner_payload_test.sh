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

function test_decode_subshell_output_writes_empty_for_empty_marker() {
  bashunit::runner::decode_subshell_output "pre##TEST_OUTPUT=_BASHUNIT_EMPTY_##ASSERTIONS_PASSED=1"

  assert_empty "$_BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT"
}

function test_decode_subshell_output_decodes_non_empty_output_to_slot() {
  local encoded
  encoded="$(bashunit::helper::encode_base64 "hello output")"
  bashunit::runner::decode_subshell_output "pre##TEST_OUTPUT=${encoded}##ASSERTIONS_PASSED=1"

  assert_same "hello output" "$_BASHUNIT_RUNNER_SUBSHELL_OUTPUT_OUT"
}

function test_extract_encoded_field_writes_value_to_slot() {
  bashunit::runner::extract_encoded_field \
    "preamble##TEST_TITLE=hello world##ASSERTIONS_PASSED=1" "TEST_TITLE"

  assert_same "hello world" "$_BASHUNIT_RUNNER_FIELD_OUT"
}

function test_extract_encoded_field_writes_empty_when_key_missing() {
  _BASHUNIT_RUNNER_FIELD_OUT="prior"
  bashunit::runner::extract_encoded_field "##ASSERTIONS_PASSED=1" "TEST_TITLE"

  assert_empty "$_BASHUNIT_RUNNER_FIELD_OUT"
}

function test_compute_total_assertions_sums_into_slot() {
  bashunit::runner::compute_total_assertions \
    "##ASSERTIONS_FAILED=1##ASSERTIONS_PASSED=2##ASSERTIONS_SKIPPED=3##ASSERTIONS_INCOMPLETE=4##ASSERTIONS_SNAPSHOT=5"

  assert_same "15" "$_BASHUNIT_RUNNER_TOTAL_OUT"
}

function test_compute_total_assertions_treats_missing_counters_as_zero() {
  bashunit::runner::compute_total_assertions "##ASSERTIONS_PASSED=2"

  assert_same "2" "$_BASHUNIT_RUNNER_TOTAL_OUT"
}

# Without the digits guard the ##KEY= strips are no-ops on a non-payload result,
# so the raw text reaches $(( )) and raises a fatal arithmetic syntax error.
function test_compute_total_assertions_treats_a_non_payload_result_as_zero() {
  bashunit::runner::compute_total_assertions "bash: line 3: syntax error near unexpected token"

  assert_same "0" "$_BASHUNIT_RUNNER_TOTAL_OUT"
}

function test_compute_total_assertions_treats_a_non_numeric_counter_as_zero() {
  bashunit::runner::compute_total_assertions "##ASSERTIONS_PASSED=2##ASSERTIONS_FAILED=oops"

  assert_same "0" "$_BASHUNIT_RUNNER_TOTAL_OUT"
}

# Builds a one-line encoded test result like execute_test_body emits.
# Args: failed passed skipped incomplete snapshot exit_code
function build_encoded_result() {
  local out="##ASSERTIONS_FAILED=$1##ASSERTIONS_PASSED=$2"
  out="$out##ASSERTIONS_SKIPPED=$3##ASSERTIONS_INCOMPLETE=$4"
  out="$out##ASSERTIONS_SNAPSHOT=$5##TEST_EXIT_CODE=$6##"
  printf '%s' "$out"
}

function test_extract_result_counts_writes_counts_to_slots() {
  bashunit::runner::extract_result_counts "$(build_encoded_result 2 3 0 0 0 5)"

  assert_same "2" "$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT"
  assert_same "3" "$_BASHUNIT_RUNNER_COUNTS_PASSED_OUT"
  assert_same "5" "$_BASHUNIT_RUNNER_COUNTS_EXIT_CODE_OUT"
}

function test_extract_result_counts_does_not_mutate_cumulative_state() {
  local before_failed="$_BASHUNIT_ASSERTIONS_FAILED"
  local before_exit="$_BASHUNIT_TEST_EXIT_CODE"

  bashunit::runner::extract_result_counts "$(build_encoded_result 9 9 0 0 0 1)"

  assert_same "$before_failed" "$_BASHUNIT_ASSERTIONS_FAILED"
  assert_same "$before_exit" "$_BASHUNIT_TEST_EXIT_CODE"
}

function test_extract_result_counts_reads_only_the_last_line() {
  local result
  result="user output mentioning ASSERTIONS_FAILED=7 should be ignored
$(build_encoded_result 1 0 0 0 0 0)"

  bashunit::runner::extract_result_counts "$result"

  assert_same "1" "$_BASHUNIT_RUNNER_COUNTS_FAILED_OUT"
}

function test_extract_subshell_type_strips_brackets_into_slot() {
  bashunit::runner::extract_subshell_type "[failed] something happened"

  assert_same "failed" "$_BASHUNIT_RUNNER_TYPE_OUT"
}

function test_format_subshell_output_strips_type_and_expands_markers() {
  bashunit::runner::format_subshell_output "[failed] line1[skipped]line2[incomplete]line3"

  local expected
  expected=$' line1\nline2\nline3'
  assert_same "$expected" "$_BASHUNIT_RUNNER_OUTPUT_OUT"
}

# Regression for #674: caller-named locals must not be silently corrupted by
# the helpers. With the global-slot return pattern the helper never touches
# caller-named variables, so a caller can freely use natural names (e.g.
# `subshell_output`, `test_execution_result`) without any shadowing risk.
function test_format_subshell_output_does_not_touch_caller_locals() {
  local subshell_output="raw"
  bashunit::runner::format_subshell_output "[failed] formatted"

  assert_same " formatted" "$_BASHUNIT_RUNNER_OUTPUT_OUT"
  assert_same "raw" "$subshell_output"
}

function test_extract_subshell_type_does_not_touch_caller_locals() {
  local subshell_output="[failed] payload"
  bashunit::runner::extract_subshell_type "$subshell_output"

  assert_same "failed" "$_BASHUNIT_RUNNER_TYPE_OUT"
  assert_same "[failed] payload" "$subshell_output"
}

function test_extract_encoded_field_does_not_touch_caller_locals() {
  local test_execution_result="##TEST_TITLE=hi##ASSERTIONS_PASSED=1"
  bashunit::runner::extract_encoded_field "$test_execution_result" "TEST_TITLE"

  assert_same "hi" "$_BASHUNIT_RUNNER_FIELD_OUT"
  assert_same "##TEST_TITLE=hi##ASSERTIONS_PASSED=1" "$test_execution_result"
}

function test_compute_total_assertions_does_not_touch_caller_locals() {
  local test_execution_result="##ASSERTIONS_PASSED=4##ASSERTIONS_FAILED=1"
  bashunit::runner::compute_total_assertions "$test_execution_result"

  assert_same "5" "$_BASHUNIT_RUNNER_TOTAL_OUT"
  assert_same "##ASSERTIONS_PASSED=4##ASSERTIONS_FAILED=1" "$test_execution_result"
}
