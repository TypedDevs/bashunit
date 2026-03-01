#!/usr/bin/env bash

# shellcheck disable=SC2329 # Test functions are invoked indirectly by bashunit
############################
# bashunit::watch::is_available
############################

function test_is_available_returns_inotifywait_when_present() {
  bashunit::mock bashunit::watch::_command_exists mock_true

  assert_equals "inotifywait" "$(bashunit::watch::is_available)"
}

function test_is_available_returns_fswatch_when_inotifywait_missing() {
  local call_count=0
  function bashunit::watch::_command_exists() {
    call_count=$((call_count + 1))
    [[ $call_count -eq 2 ]]
  }

  assert_equals "fswatch" "$(bashunit::watch::is_available)"
}

function test_is_available_returns_empty_when_no_tool_found() {
  bashunit::mock bashunit::watch::_command_exists mock_false

  assert_empty "$(bashunit::watch::is_available)"
}

############################
# bashunit::watch::run — error path (no tool)
# run() calls exit 1, so we must capture it in a subshell
############################

function test_run_exits_nonzero_when_no_tool_available() {
  bashunit::mock bashunit::watch::is_available echo ""

  local exit_code=0
  (bashunit::watch::run "tests/" >/dev/null 2>&1) || exit_code=$?

  assert_greater_than "0" "$exit_code"
}

function test_run_error_message_mentions_required_tools() {
  bashunit::mock bashunit::watch::is_available echo ""

  local output
  output=$(bashunit::watch::run "tests/" 2>&1) || true

  assert_contains "inotifywait" "$output"
  assert_contains "fswatch" "$output"
}

function test_run_error_message_includes_install_hints() {
  bashunit::mock bashunit::watch::is_available echo ""

  local output
  output=$(bashunit::watch::run "tests/" 2>&1) || true

  assert_contains "apt install inotify-tools" "$output"
  assert_contains "brew install fswatch" "$output"
}

############################
# bashunit::watch::wait_for_change — tool dispatch
############################

function test_wait_for_change_calls_inotifywait_on_linux() {
  bashunit::spy inotifywait

  bashunit::watch::wait_for_change "inotifywait" "tests/" 2>/dev/null || true

  assert_have_been_called inotifywait
}

function test_wait_for_change_calls_fswatch_on_macos() {
  bashunit::spy fswatch

  bashunit::watch::wait_for_change "fswatch" "tests/" 2>/dev/null || true

  assert_have_been_called fswatch
}

function test_wait_for_change_does_nothing_for_unknown_tool() {
  bashunit::spy inotifywait
  bashunit::spy fswatch

  bashunit::watch::wait_for_change "unknown-tool" "tests/" 2>/dev/null || true

  assert_not_called inotifywait
  assert_not_called fswatch
}
