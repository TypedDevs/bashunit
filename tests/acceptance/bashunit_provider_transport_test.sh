#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  PROVIDER_TRANSPORT_FIXTURES="$(bashunit::temp_dir provider_transport)"
}

function provide_transport_setup_failures() {
  bashunit::data_set --no-parallel mktemp
  bashunit::data_set --parallel mktemp
  bashunit::data_set --no-parallel directory
  bashunit::data_set --parallel directory
}

# @data_provider provide_transport_setup_failures
function test_provider_storage_setup_failure_is_reported_once() {
  local mode="$1" failure="$2"
  local dir="$PROVIDER_TRANSPORT_FIXTURES/setup_${mode#--}_$failure"
  mkdir -p "$dir"
  {
    if [ "$failure" = mktemp ]; then
      printf '%s\n' 'function fail_provider_mktemp() { return 1; }
function set_up_before_script() { MKTEMP=fail_provider_mktemp; }'
    else
      printf '%s\n' 'function set_up_before_script() {
  function bashunit::env::ensure_run_output_dir() { return 1; }
}'
    fi
    printf '%s\n' 'function test_before_provider_storage_failure() { assert_same 1 1; }
function provide_setup_failure_rows() { bashunit::data_set first; bashunit::data_set second; }
# @data_provider provide_setup_failure_rows
function test_row_with_unavailable_storage() {
  printf executed >"$PROVIDER_BODY_MARKER"
  assert_same first "${1-}"
}'
  } >"$dir/setup_failure_test.sh"

  local output code=0
  output="$(PROVIDER_BODY_MARKER="$dir/body" ./bashunit "$mode" \
    --env tests/acceptance/fixtures/.env.default --report-json "$dir/report.json" \
    "$dir/setup_failure_test.sh" 2>&1)" || code=$?
  output="$(printf '%s' "$output" | strip_ansi)"

  assert_same 1 "$code"
  assert_contains "data provider 'provide_setup_failure_rows'" "$output"
  assert_contains "1 passed" "$output"
  assert_contains "1 failed" "$output"
  assert_contains "2 total" "$output"
  assert_contains '"total": 2, "passed": 1, "failed": 1' "$(<"$dir/report.json")"
  assert_file_not_exists "$dir/body"
}

function provide_transport_io_failures() {
  bashunit::data_set --no-parallel write
  bashunit::data_set --parallel write
  bashunit::data_set --no-parallel read
  bashunit::data_set --parallel read
}

# @data_provider provide_transport_io_failures
function test_provider_storage_io_failure_does_not_execute_the_test_body() {
  local mode="$1" failure="$2"
  local dir="$PROVIDER_TRANSPORT_FIXTURES/io_${mode#--}_$failure"
  mkdir -p "$dir"
  {
    if [ "$failure" = write ]; then
      printf '%s\n' 'function unusable_provider_storage() { printf "%s\n" "$_BASHUNIT_RUN_OUTPUT_DIR"; }
function set_up_before_script() { MKTEMP=unusable_provider_storage; }'
    else
      printf '%s\n' 'function set_up_before_script() {
  function bashunit::runner::parse_data_provider_args() {
    rm -f "$provider_arg_file"
    printf "%s\0" row
  }
}'
    fi
    printf '%s\n' 'function test_before_provider_io_failure() { assert_same 1 1; }
function provide_io_failure_rows() { bashunit::data_set first; bashunit::data_set second; }
# @data_provider provide_io_failure_rows
function test_row_with_unreadable_storage() {
  printf executed >"$PROVIDER_BODY_MARKER"
  assert_same 0 "$#"
}'
  } >"$dir/io_failure_test.sh"

  local output code=0
  output="$(PROVIDER_BODY_MARKER="$dir/body" ./bashunit "$mode" \
    --env tests/acceptance/fixtures/.env.default --report-json "$dir/report.json" \
    "$dir/io_failure_test.sh" 2>&1)" || code=$?
  output="$(printf '%s' "$output" | strip_ansi)"

  assert_same 1 "$code"
  assert_contains "data provider 'provide_io_failure_rows'" "$output"
  assert_contains "1 passed" "$output"
  assert_contains "1 failed" "$output"
  assert_contains "2 total" "$output"
  assert_contains '"total": 2, "passed": 1, "failed": 1' "$(<"$dir/report.json")"
  assert_file_not_exists "$dir/body"
}

function provide_transport_modes() {
  printf '%s\n' --no-parallel --parallel
}

# @data_provider provide_transport_modes
function test_provider_rows_restore_a_scratch_directory_removed_by_the_previous_row() {
  local mode="$1"
  local dir="$PROVIDER_TRANSPORT_FIXTURES/restore_${mode#--}"
  mkdir -p "$dir"
  : >"$dir/public_files"
  printf '%s\n' '# bashunit: no-parallel-tests
function provide_rows_across_scratch_loss() { bashunit::data_set first; bashunit::data_set second; }
# @data_provider provide_rows_across_scratch_loss
function test_row_after_scratch_loss() {
  assert_same 1 "$#"
  assert_not_empty "${1-}"
  printf "%s\n" "$1" >>"$PROVIDER_ROWS_MARKER"
  if ! bashunit::check_os::is_windows; then
    find "$_BASHUNIT_RUN_OUTPUT_DIR" -name "provider-args.*" -perm -004 -print >>"$PROVIDER_PUBLIC_FILES"
  fi
  if [ "${1-}" = first ]; then
    printf "Removing scratch directory: %s\n" "$_BASHUNIT_RUN_OUTPUT_DIR"
    bashunit::env::cleanup_run_output_dir
  fi
}' >"$dir/scratch_loss_test.sh"

  local output code=0
  output="$(PROVIDER_ROWS_MARKER="$dir/rows" PROVIDER_PUBLIC_FILES="$dir/public_files" \
    ./bashunit "$mode" --env tests/acceptance/fixtures/.env.default \
    "$dir/scratch_loss_test.sh" 2>&1)" || code=$?
  output="$(printf '%s' "$output" | strip_ansi)"

  assert_same 0 "$code"
  assert_same $'first\nsecond' "$(<"$dir/rows")"
  assert_empty "$(<"$dir/public_files")"
  assert_not_contains "No such file or directory" "$output"
}
