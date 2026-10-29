#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  COVERAGE_PATH_BASHUNIT="$PWD/bashunit"
}

function _coverage_path_project() {
  local dir
  dir="$(bashunit::temp_dir coverage_paths)"
  printf 'function covered_path_value() { COVERED_PATH_VALUE=covered; }\n' >"$dir/lib.sh"
  {
    printf 'source "%s/lib.sh"\n' "$dir"
    echo 'function test_coverage_path_fixture() {'
    echo '  covered_path_value'
    echo '  assert_same covered "$COVERED_PATH_VALUE"'
    printf '  touch "%s/ran"\n' "$dir"
    echo '  if [ -n "${COVERAGE_PATH_MUTATION:-}" ]; then mkdir -p "$COVERAGE_PATH_MUTATION"; fi'
    echo '}'
  } >"$dir/suite_test.sh"
  printf '%s\n' "$dir"
}

function _run_coverage_path_project() {
  local dir="$1"
  shift
  (
    cd "$dir" || exit 1
    BASHUNIT_COVERAGE_PATHS="$dir/lib.sh" BASHUNIT_COVERAGE_REPORT="${COVERAGE_PATH_LCOV:-}" \
      "$COVERAGE_PATH_BASHUNIT" --skip-env-file --no-color --no-parallel "$@" "$dir/suite_test.sh" 2>&1
  )
}

function provide_uncreatable_coverage_paths() {
  bashunit::data_set --coverage-report 'BASHUNIT_COVERAGE_REPORT (--coverage-report)'
  bashunit::data_set --coverage-report-html 'BASHUNIT_COVERAGE_REPORT_HTML (--coverage-report-html)'
}

# @data_provider provide_uncreatable_coverage_paths
function test_coverage_report_paths_fail_before_any_test_runs() {
  local flag="$1" setting="$2" dir status=0 output
  dir="$(_coverage_path_project)"
  printf 'blocked\n' >"$dir/blocker"

  output=$(_run_coverage_path_project "$dir" "$flag" "$dir/blocker/report") || status=$?

  assert_general_error "" "" "$status"
  assert_contains "$setting cannot be written" "$output"
  assert_not_contains 'report written to:' "$output"
  assert_file_not_exists "$dir/ran"
}

function provide_late_coverage_write_failures() {
  bashunit::data_set --coverage-report lcov.info lcov.info 'Coverage report'
  bashunit::data_set --coverage-report-html html html/index.html 'Coverage HTML report'
  bashunit::data_set --coverage-report-html html html/files/lib_sh.html 'Coverage HTML report'
  bashunit::data_set --coverage-report-html html html/files 'Coverage HTML report'
}

# @data_provider provide_uncreatable_coverage_paths
function test_coverage_report_paths_from_the_environment_fail_before_tests() {
  local flag="$1" setting="$2" dir status=0 output
  dir="$(_coverage_path_project)"
  printf 'blocked\n' >"$dir/blocker"

  if [ "$flag" = --coverage-report ]; then
    output=$(BASHUNIT_COVERAGE=true COVERAGE_PATH_LCOV="$dir/blocker/report" \
      _run_coverage_path_project "$dir") || status=$?
  else
    output=$(BASHUNIT_COVERAGE=true BASHUNIT_COVERAGE_REPORT_HTML="$dir/blocker/report" \
      _run_coverage_path_project "$dir") || status=$?
  fi

  assert_general_error "" "" "$status"
  assert_contains "$setting cannot be written" "$output"
  assert_file_not_exists "$dir/ran"
}

function test_disabled_coverage_does_not_validate_unused_report_paths() {
  local dir
  dir="$(_coverage_path_project)"
  printf 'blocked\n' >"$dir/blocker"

  BASHUNIT_COVERAGE=false COVERAGE_PATH_LCOV="$dir/blocker/report" \
    _run_coverage_path_project "$dir" >/dev/null

  assert_file_exists "$dir/ran"
}

# @data_provider provide_late_coverage_write_failures
function test_coverage_report_write_errors_fail_the_run() {
  local flag="$1" target="$2" blocked="$3" label="$4" dir status=0 output
  dir="$(_coverage_path_project)"
  if [ "$blocked" = html/files ]; then
    mkdir "$dir/html"
    printf 'blocked\n' >"$dir/html/files"
    blocked=""
  fi

  output=$(COVERAGE_PATH_MUTATION="${blocked:+$dir/$blocked}" \
    _run_coverage_path_project "$dir" "$flag" "$dir/$target") || status=$?

  assert_general_error "" "" "$status"
  assert_file_exists "$dir/ran"
  assert_contains "Error: $label could not be written" "$output"
  assert_not_contains "$label written to:" "$output"
}

function test_coverage_reports_accept_existing_output_paths() {
  local dir
  dir="$(_coverage_path_project)"
  mkdir "$dir/html"
  printf 'old report\n' >"$dir/lcov.info"

  _run_coverage_path_project "$dir" --coverage-report "$dir/lcov.info" \
    --coverage-report-html "$dir/html" >/dev/null

  assert_contains 'SF:' "$(cat "$dir/lcov.info")"
  assert_file_exists "$dir/html/index.html"
}

function test_coverage_report_creates_missing_default_directory() {
  local dir
  dir="$(_coverage_path_project)"

  _run_coverage_path_project "$dir" --coverage-report coverage/lcov.info >/dev/null

  assert_file_exists "$dir/coverage/lcov.info"
}
