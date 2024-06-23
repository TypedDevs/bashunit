#!/bin/bash

_ERROR_LOG=temp_error.log

function tear_down() {
  rm $_ERROR_LOG
}

function test_redirect_error_with_log() {
  exec 2>&3 2>$_ERROR_LOG

  _="$(render_into_error_fd_and_exit "arg1" "arg2")"
  assert_general_error

  local error_output
  error_output=$(<$_ERROR_LOG)
  assert_equals "arg1 arg2" "$error_output"
}

function test_redirect_error_without_log() {
  exec 2>&3 2>/dev/null

  _="$(render_into_error_fd_and_exit "...args")"
  assert_general_error
}

function render_into_error_fd_and_exit() {
  echo "$*" >&2
  exit 1
}
