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

# The message is one line because it is *one line of the capture* -- the
# diagnostic itself, with its source prefix stripped. It used to be the whole
# capture with the newlines deleted, which glued unrelated output onto the end
# ("...command not foundextra"). Anything else the test printed is display
# output, and stays there.
function test_detect_runtime_error_reports_the_diagnostic_line_not_the_whole_capture() {
  local input=$'bash: line 1: foo: command not found\nextra'
  bashunit::runner::detect_runtime_error "$input"

  assert_same "line 1: foo: command not found" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
  assert_same "$input" "$_BASHUNIT_RUNNER_RUNTIME_OUTPUT_OUT"
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

# bash translates its diagnostics, so the English phrase list matches nothing
# under a Spanish or Japanese locale and a genuine failure-to-run was reported
# as a plain assertion failure. The exit code carries the same information and
# is locale-independent: 127 is "could not find it", 126 "could not run it".
function test_detect_runtime_error_uses_the_exit_code_when_the_text_is_translated() {
  bashunit::runner::detect_runtime_error \
    "/tmp/x.sh: línea 1: foo: orden no encontrada" 127

  assert_not_empty "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

function test_detect_runtime_error_uses_the_exit_code_for_not_executable() {
  bashunit::runner::detect_runtime_error \
    "/tmp/x.sh: ligne 1: foo: Permission non accordée" 126

  assert_not_empty "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

# A failing assertion is not a runtime error, whatever the exit code says about
# the test function itself.
function test_detect_runtime_error_ignores_an_ordinary_failure_exit_code() {
  bashunit::runner::detect_runtime_error "Expected 'a' but got 'b'" 1

  assert_empty "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

# English text still wins, so the message stays as informative as before.
function test_detect_runtime_error_prefers_the_matched_text_over_the_exit_code() {
  bashunit::runner::detect_runtime_error \
    "/tmp/x.sh: line 1: foo: command not found" 127

  assert_contains "command not found" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}

# A test can both fail an assertion and hit a runtime error. bashunit prints the
# failure inside the capture subshell, so its own rendering sits in the capture
# ahead of the shell's diagnostic. Extracting from the whole capture then strips
# to the first ": " anywhere -- which lands inside "✗ Failed: <name>" -- and the
# reported error becomes the failure text with the diagnostic glued on the end.
function test_detect_runtime_error_reports_only_the_diagnostic_not_the_captured_failure() {
  local input="✗ Failed: Both
    Expected 'a'
    but got  'b'
    at f_test.sh:2
f_test.sh: line 4: nope: command not found"

  bashunit::runner::detect_runtime_error "$input"

  assert_same "line 4: nope: command not found" "$_BASHUNIT_RUNNER_RUNTIME_ERROR_OUT"
}
