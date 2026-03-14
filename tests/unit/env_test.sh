#!/usr/bin/env bash

# shellcheck disable=SC2155

# @data_provider provide_boolean_flags_true
function test_env_flag_returns_success_when_true() {
  local var_name="$1"
  local fn_name="$2"

  local original_value="${!var_name}"
  eval "export $var_name=true"

  "$fn_name"
  assert_successful_code "$?"

  eval "export $var_name='$original_value'"
}

function provide_boolean_flags_true() {
  bashunit::data_set "BASHUNIT_PARALLEL_RUN" "bashunit::env::is_parallel_run_enabled"
  bashunit::data_set "BASHUNIT_SHOW_HEADER" "bashunit::env::is_show_header_enabled"
  bashunit::data_set "BASHUNIT_HEADER_ASCII_ART" "bashunit::env::is_header_ascii_art_enabled"
  bashunit::data_set "BASHUNIT_SIMPLE_OUTPUT" "bashunit::env::is_simple_output_enabled"
  bashunit::data_set "BASHUNIT_STOP_ON_FAILURE" "bashunit::env::is_stop_on_failure_enabled"
  bashunit::data_set "BASHUNIT_SHOW_EXECUTION_TIME" "bashunit::env::is_show_execution_time_enabled"
  bashunit::data_set "BASHUNIT_INTERNAL_LOG" "bashunit::env::is_internal_log_enabled"
  bashunit::data_set "BASHUNIT_VERBOSE" "bashunit::env::is_verbose_enabled"
  bashunit::data_set "BASHUNIT_BENCH_MODE" "bashunit::env::is_bench_mode_enabled"
  bashunit::data_set "BASHUNIT_NO_OUTPUT" "bashunit::env::is_no_output_enabled"
  bashunit::data_set "BASHUNIT_SHOW_SKIPPED" "bashunit::env::is_show_skipped_enabled"
  bashunit::data_set "BASHUNIT_SHOW_INCOMPLETE" "bashunit::env::is_show_incomplete_enabled"
  bashunit::data_set "BASHUNIT_STRICT_MODE" "bashunit::env::is_strict_mode_enabled"
  bashunit::data_set "BASHUNIT_STOP_ON_ASSERTION_FAILURE" "bashunit::env::is_stop_on_assertion_failure_enabled"
  bashunit::data_set "BASHUNIT_SKIP_ENV_FILE" "bashunit::env::is_skip_env_file_enabled"
  bashunit::data_set "BASHUNIT_LOGIN_SHELL" "bashunit::env::is_login_shell_enabled"
  bashunit::data_set "BASHUNIT_FAILURES_ONLY" "bashunit::env::is_failures_only_enabled"
  bashunit::data_set "BASHUNIT_SHOW_OUTPUT_ON_FAILURE" "bashunit::env::is_show_output_on_failure_enabled"
  bashunit::data_set "BASHUNIT_NO_PROGRESS" "bashunit::env::is_no_progress_enabled"
  bashunit::data_set "BASHUNIT_NO_COLOR" "bashunit::env::is_no_color_enabled"
  bashunit::data_set "BASHUNIT_COVERAGE" "bashunit::env::is_coverage_enabled"
}

# @data_provider provide_boolean_flags_false
function test_env_flag_returns_failure_when_false() {
  local var_name="$1"
  local fn_name="$2"

  local original_value="${!var_name}"
  eval "export $var_name=false"

  if "$fn_name"; then
    eval "export $var_name='$original_value'"
    fail "Expected $fn_name to return failure when $var_name=false"
    return
  fi

  eval "export $var_name='$original_value'"
}

function provide_boolean_flags_false() {
  bashunit::data_set "BASHUNIT_PARALLEL_RUN" "bashunit::env::is_parallel_run_enabled"
  bashunit::data_set "BASHUNIT_SHOW_HEADER" "bashunit::env::is_show_header_enabled"
  bashunit::data_set "BASHUNIT_SIMPLE_OUTPUT" "bashunit::env::is_simple_output_enabled"
  bashunit::data_set "BASHUNIT_STOP_ON_FAILURE" "bashunit::env::is_stop_on_failure_enabled"
  bashunit::data_set "BASHUNIT_VERBOSE" "bashunit::env::is_verbose_enabled"
  bashunit::data_set "BASHUNIT_NO_OUTPUT" "bashunit::env::is_no_output_enabled"
  bashunit::data_set "BASHUNIT_STRICT_MODE" "bashunit::env::is_strict_mode_enabled"
  bashunit::data_set "BASHUNIT_NO_COLOR" "bashunit::env::is_no_color_enabled"
  bashunit::data_set "BASHUNIT_COVERAGE" "bashunit::env::is_coverage_enabled"
}

function test_is_dev_mode_enabled_when_dev_log_set() {
  local original="$BASHUNIT_DEV_LOG"
  export BASHUNIT_DEV_LOG="/tmp/dev.log"

  bashunit::env::is_dev_mode_enabled
  assert_successful_code "$?"

  export BASHUNIT_DEV_LOG="$original"
}

function test_is_dev_mode_disabled_when_dev_log_empty() {
  local original="$BASHUNIT_DEV_LOG"
  export BASHUNIT_DEV_LOG=""

  if bashunit::env::is_dev_mode_enabled; then
    export BASHUNIT_DEV_LOG="$original"
    fail "Expected is_dev_mode_enabled to return failure when BASHUNIT_DEV_LOG is empty"
    return
  fi

  export BASHUNIT_DEV_LOG="$original"
}

function test_is_tap_output_enabled_when_format_is_tap() {
  local original="$BASHUNIT_OUTPUT_FORMAT"
  export BASHUNIT_OUTPUT_FORMAT="tap"

  bashunit::env::is_tap_output_enabled
  assert_successful_code "$?"

  export BASHUNIT_OUTPUT_FORMAT="$original"
}

function test_is_tap_output_disabled_when_format_is_not_tap() {
  local original="$BASHUNIT_OUTPUT_FORMAT"
  export BASHUNIT_OUTPUT_FORMAT=""

  if bashunit::env::is_tap_output_enabled; then
    export BASHUNIT_OUTPUT_FORMAT="$original"
    fail "Expected is_tap_output_enabled to return failure when format is empty"
    return
  fi

  export BASHUNIT_OUTPUT_FORMAT="$original"
}

function test_active_internet_connection_returns_failure_when_no_network() {
  local original="${BASHUNIT_NO_NETWORK:-}"
  export BASHUNIT_NO_NETWORK="true"

  if bashunit::env::active_internet_connection; then
    export BASHUNIT_NO_NETWORK="$original"
    fail "Expected active_internet_connection to fail when BASHUNIT_NO_NETWORK=true"
    return
  fi

  export BASHUNIT_NO_NETWORK="$original"
}

function test_find_terminal_width_returns_a_number() {
  local result
  result=$(bashunit::env::find_terminal_width)

  assert_matches "^[0-9]+$" "$result"
}

function test_find_terminal_width_fallback_returns_100() {
  bashunit::mock tput true
  bashunit::mock stty true

  local result
  result=$(bashunit::env::find_terminal_width)

  assert_equals "100" "$result"
}

function test_print_verbose_outputs_env_var_names() {
  local original="$BASHUNIT_VERBOSE"
  export BASHUNIT_VERBOSE="true"

  local output
  output=$(bashunit::env::print_verbose)

  assert_contains "BASHUNIT_DEFAULT_PATH" "$output"
  assert_contains "BASHUNIT_PARALLEL_RUN" "$output"
  assert_contains "BASHUNIT_VERBOSE" "$output"
  assert_contains "BASHUNIT_COVERAGE" "$output"

  export BASHUNIT_VERBOSE="$original"
}
