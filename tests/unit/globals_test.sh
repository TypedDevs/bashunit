#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  BASHUNIT_LOG_PATH=$(temp_file)
  export BASHUNIT_LOG_PATH
}

function tear_down_after_script() {
  rm "$BASHUNIT_LOG_PATH"
}

function test_globals_current_dir() {
  assert_same "tests/unit" "$(current_dir)"
}

function test_globals_current_filename() {
  assert_same "globals_test.sh" "$(current_filename)"
}

function test_globals_current_timestamp() {
  assert_matches \
    "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$" \
    "$(current_timestamp)"
}

function test_globals_is_command_available() {
  assert_successful_code "$(is_command_available ls)"
}

function test_globals_is_command_not_available() {
  assert_general_error "$(is_command_available non-existing-command)"
}

function test_globals_random_str_default() {
  assert_matches "^[A-Za-z0-9]{6}$" "$(random_str)"
}

function test_globals_random_str_custom() {
  assert_matches "^[A-Za-z0-9]{3}$" "$(random_str 3)"
}

function test_globals_temp_file() {
  # shellcheck disable=SC2155
  local temp_file=$(temp_file)
  assert_file_exists "$temp_file"
  cleanup_temp_files
  assert_file_not_exists "$temp_file"
}

function test_globals_temp_dir() {
  # shellcheck disable=SC2155
  local temp_dir=$(temp_dir)
  assert_directory_exists "$temp_dir"
  cleanup_temp_files
  assert_directory_not_exists "$temp_dir"
}

function test_globals_log_info() {
  log_info "hello," "world"

  assert_file_contains "$BASHUNIT_LOG_PATH" "hello, worl"
}

function test_globals_log_error() {
  log_error "hello," "luna"

  assert_file_contains "$BASHUNIT_LOG_PATH" "hello, luna"
}
