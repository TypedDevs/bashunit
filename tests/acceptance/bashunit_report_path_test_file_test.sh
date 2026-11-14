#!/usr/bin/env bash
set -euo pipefail

# A report flag whose value was left out takes the next argument as its path.
# When that argument is a test file, the report used to overwrite it.

function set_up_before_script() {
  REPORT_PATH_BASHUNIT="$PWD/bashunit"
}

function _report_path_project() {
  local dir
  dir="$(bashunit::temp_dir report_path)"
  printf 'function test_report_path_fixture() { assert_same 1 1; }\n' >"$dir/a_test.sh"
  printf '%s\n' "$dir"
}

function provide_report_flags() {
  bashunit::data_set --report-json
  bashunit::data_set --report-html
  bashunit::data_set --report-tap
  bashunit::data_set --report-md
  bashunit::data_set --log-junit
  bashunit::data_set --log-gha
  bashunit::data_set --coverage-report
  bashunit::data_set --coverage-report-cobertura
  bashunit::data_set --coverage-report-html
}

# @data_provider provide_report_flags
function test_report_flag_refuses_to_overwrite_the_test_file_after_it() {
  local flag=$1 dir output ec=0
  dir="$(_report_path_project)"
  local before
  before="$(cat "$dir/a_test.sh")"

  output=$(cd "$dir" && "$REPORT_PATH_BASHUNIT" --skip-env-file --no-color "$flag" a_test.sh 2>&1) || ec=$?

  assert_same 1 "$ec"
  assert_contains "needs a report file, got the shell script 'a_test.sh'" "$output"
  assert_same "$before" "$(cat "$dir/a_test.sh")"
}

function test_report_flag_still_overwrites_an_existing_report_file() {
  local dir output ec=0
  dir="$(_report_path_project)"
  printf 'old\n' >"$dir/report.json"

  output=$(cd "$dir" &&
    "$REPORT_PATH_BASHUNIT" --skip-env-file --no-color --report-json report.json a_test.sh 2>&1) || ec=$?

  assert_same 0 "$ec"
  assert_contains '"passed": 1' "$(cat "$dir/report.json")"
}

function test_report_env_var_refuses_a_shell_script() {
  local dir output ec=0
  dir="$(_report_path_project)"
  printf 'echo helper\n' >"$dir/helper.sh"

  output=$(cd "$dir" &&
    BASHUNIT_REPORT_HTML=helper.sh "$REPORT_PATH_BASHUNIT" --skip-env-file --no-color a_test.sh 2>&1) || ec=$?

  assert_same 1 "$ec"
  assert_contains "BASHUNIT_REPORT_HTML needs a report file, got the shell script 'helper.sh'" "$output"
  assert_same "echo helper" "$(cat "$dir/helper.sh")"
}

function provide_inline_filter_values() {
  bashunit::data_set 'a_test.sh::test_report_path_fixture'
  bashunit::data_set 'a_test.sh:1'
}

# @data_provider provide_inline_filter_values
function test_report_flag_refuses_a_test_file_with_an_inline_filter() {
  local value=$1 dir output ec=0
  dir="$(_report_path_project)"

  output=$(cd "$dir" && "$REPORT_PATH_BASHUNIT" --skip-env-file --no-color --report-json "$value" 2>&1) || ec=$?

  assert_same 1 "$ec"
  assert_contains "needs a report file, got the shell script '$value'" "$output"
  assert_file_not_exists "$dir/$value"
}

function _bench_path_project() {
  local dir
  dir="$(bashunit::temp_dir bench_report_path)"
  printf 'function bench_report_path_fixture() { :; }\n' >"$dir/a_bench.sh"
  printf '%s\n' "$dir"
}

function provide_bench_report_settings() {
  bashunit::data_set --report-json BASHUNIT_BENCH_REPORT_JSON
  bashunit::data_set --report-junit BASHUNIT_BENCH_REPORT_JUNIT
  bashunit::data_set --baseline-update BASHUNIT_BENCH_BASELINE_UPDATE
}

# @data_provider provide_bench_report_settings
function test_bench_report_flag_refuses_to_overwrite_the_bench_file() {
  local flag=$1 dir output ec=0 before
  dir="$(_bench_path_project)"
  before="$(cat "$dir/a_bench.sh")"

  output=$(cd "$dir" &&
    "$REPORT_PATH_BASHUNIT" bench --skip-env-file --no-color "$flag" a_bench.sh 2>&1) || ec=$?

  assert_same 1 "$ec"
  assert_contains "needs a report file, got the shell script 'a_bench.sh'" "$output"
  assert_same "$before" "$(cat "$dir/a_bench.sh")"
}

# @data_provider provide_bench_report_settings
function test_bench_report_env_var_refuses_the_bench_file() {
  local setting=$2 dir output ec=0 before
  dir="$(_bench_path_project)"
  before="$(cat "$dir/a_bench.sh")"

  output=$(cd "$dir" &&
    env "$setting=a_bench.sh" "$REPORT_PATH_BASHUNIT" bench --skip-env-file --no-color a_bench.sh 2>&1) || ec=$?

  assert_same 1 "$ec"
  assert_contains "$setting needs a report file, got the shell script 'a_bench.sh'" "$output"
  assert_same "$before" "$(cat "$dir/a_bench.sh")"
}
