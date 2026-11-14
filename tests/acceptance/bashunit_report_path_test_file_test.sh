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
