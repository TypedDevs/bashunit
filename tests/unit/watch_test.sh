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

function test_is_available_returns_polling_when_no_tool_found() {
  bashunit::mock bashunit::watch::_command_exists mock_false

  assert_equals "polling" "$(bashunit::watch::is_available)"
}

############################
# bashunit::watch::run — polling fallback (no inotifywait/fswatch)
# run() loops forever, so mock wait_for_change to exit and break the loop.
############################

function test_run_falls_back_to_polling_when_no_tool() {
  bashunit::mock bashunit::watch::is_available echo "polling"
  bashunit::mock bashunit::watch::run_tests true
  function bashunit::watch::wait_for_change() { exit 0; }

  local output
  output=$( (bashunit::watch::run "tests/") 2>&1)

  assert_contains "polling" "$output"
}

function test_run_polling_notice_keeps_install_hints() {
  bashunit::mock bashunit::watch::is_available echo "polling"
  bashunit::mock bashunit::watch::run_tests true
  function bashunit::watch::wait_for_change() { exit 0; }

  local output
  output=$( (bashunit::watch::run "tests/") 2>&1)

  assert_contains "inotify-tools" "$output"
  assert_contains "fswatch" "$output"
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

# bashunit::main::cmd_watch — filter passthrough

function test_cmd_watch_forwards_filter_after_path() {
  bashunit::mock bashunit::watch::run echo

  local output
  output=$(bashunit::main::cmd_watch "tests/" "--filter" "my_test")

  assert_contains "tests/" "$output"
  assert_contains "--filter my_test" "$output"
}

function test_cmd_watch_extracts_path_when_filter_first() {
  bashunit::mock bashunit::watch::run echo

  local output
  output=$(bashunit::main::cmd_watch "--filter" "my_test" "tests/")

  assert_contains "tests/" "$output"
  assert_contains "--filter my_test" "$output"
}

function test_cmd_watch_defaults_path_to_dot() {
  bashunit::mock bashunit::watch::run echo

  local output
  output=$(bashunit::main::cmd_watch "--filter" "my_test")

  assert_contains "." "$output"
  assert_contains "--filter my_test" "$output"
}
