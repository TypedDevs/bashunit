#!/usr/bin/env bash

function test_detect_runtime_error_returns_empty_when_input_is_empty() {
  bashunit::runner::detect_runtime_error ""

  assert_empty "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_returns_empty_when_no_known_error() {
  bashunit::runner::detect_runtime_error "all good here"

  assert_empty "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_matches_command_not_found() {
  bashunit::runner::detect_runtime_error "script.sh: line 3: foo: command not found"

  assert_same "line 3: foo: command not found" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_matches_syntax_error() {
  bashunit::runner::detect_runtime_error "bash: -c: line 1: syntax error near unexpected token"

  assert_same "-c: line 1: syntax error near unexpected token" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_matches_killed() {
  bashunit::runner::detect_runtime_error "process: killed"

  assert_same "killed" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_strips_newlines_from_extracted_message() {
  local input=$'bash: line 1: foo: command not found\nextra'
  bashunit::runner::detect_runtime_error "$input"

  assert_same "line 1: foo: command not foundextra" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_matches_unexpected_eof() {
  bashunit::runner::detect_runtime_error "bash: line 5: unexpected EOF while looking for matching"

  assert_same "line 5: unexpected EOF while looking for matching" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_extracts_and_hides_assertion_usage_marker() {
  local input=$'before\nbashunit: assertion usage error: assert_same expects 2 arguments, got 1\nafter'

  bashunit::runner::detect_runtime_error "$input"

  assert_same "assert_same expects 2 arguments, got 1" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
  assert_same $'before\nafter' "$_BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT"
}

function test_detect_runtime_error_ignores_indented_assertion_usage_marker() {
  local input="  bashunit: assertion usage error: nested output"

  bashunit::runner::detect_runtime_error "$input"

  assert_empty "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
  assert_same "$input" "$_BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT"
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
