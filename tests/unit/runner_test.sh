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

function test_sync_coverage_flag_sets_one_when_enabled() {
  local _orig="${BASHUNIT_COVERAGE-}"
  BASHUNIT_COVERAGE="true"
  bashunit::runner::sync_coverage_flag
  assert_same "1" "$_BASHUNIT_COVERAGE_ON"
  BASHUNIT_COVERAGE="$_orig"
  bashunit::runner::sync_coverage_flag
}

function test_sync_coverage_flag_sets_zero_when_disabled() {
  local _orig="${BASHUNIT_COVERAGE-}"
  BASHUNIT_COVERAGE="false"
  bashunit::runner::sync_coverage_flag
  assert_same "0" "$_BASHUNIT_COVERAGE_ON"
  BASHUNIT_COVERAGE="$_orig"
  bashunit::runner::sync_coverage_flag
}

function test_sync_coverage_flag_sets_zero_when_unset() {
  local _orig="${BASHUNIT_COVERAGE-}"
  unset BASHUNIT_COVERAGE
  bashunit::runner::sync_coverage_flag
  assert_same "0" "$_BASHUNIT_COVERAGE_ON"
  BASHUNIT_COVERAGE="$_orig"
  bashunit::runner::sync_coverage_flag
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

function test_classify_kill_signal_sigkill_mentions_oom() {
  local output
  output="$(bashunit::runner::classify_kill_signal 137)"

  assert_contains "SIGKILL" "$output"
  assert_contains "memory" "$output"
}

function test_classify_kill_signal_sigterm() {
  assert_contains "SIGTERM" "$(bashunit::runner::classify_kill_signal 143)"
}

function test_classify_kill_signal_timeout() {
  assert_contains "Timed out" "$(bashunit::runner::classify_kill_signal 124)"
}

function test_classify_kill_signal_sigint() {
  assert_contains "SIGINT" "$(bashunit::runner::classify_kill_signal 130)"
}

function test_classify_kill_signal_generic_signal() {
  assert_contains "signal 6" "$(bashunit::runner::classify_kill_signal 134)"
}

function test_classify_kill_signal_empty_for_normal_exit() {
  assert_empty "$(bashunit::runner::classify_kill_signal 1)"
}

function test_supports_reliable_pipefail_matches_bash_version() {
  # Reliable on Bash >= 3.1; Bash 3.0 ships a broken pipefail.
  local expected_rc=0
  if [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -eq 0 ]; then
    expected_rc=1
  fi

  local actual_rc=0
  bashunit::runner::_supports_reliable_pipefail || actual_rc=$?
  assert_same "$expected_rc" "$actual_rc"
}
