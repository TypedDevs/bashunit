#!/usr/bin/env bash
set -euo pipefail

_ERROR_LOG=temp_error.log

function tear_down() {
  rm -f "$_ERROR_LOG"
}

function test_redirect_error_with_log() {
  exec 2>&3 2>$_ERROR_LOG

  local exit_code=0
  _="$(render_into_error_fd_and_exit "arg1" "arg2")" || exit_code=$?
  assert_same 1 "$exit_code"

  local error_output
  error_output=$(<$_ERROR_LOG)
  assert_same "arg1 arg2" "$error_output"
}

function test_redirect_error_without_log() {
  exec 2>&3 2>/dev/null

  local exit_code=0
  _="$(render_into_error_fd_and_exit "...args")" || exit_code=$?
  assert_same 1 "$exit_code"
}

function test_echo_does_not_break_test_execution_result() {
  local exit_code=0
  _="$(render_into_error_fd_and_exit "...args")" || exit_code=$?
  assert_same 1 "$exit_code"
}

function render_into_error_fd_and_exit() {
  echo "$*" >&2
  exit 1
}
