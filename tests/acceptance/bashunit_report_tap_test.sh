#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_report_tap_writes_a_valid_tap_file() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh
  local report=report.tap

  # The fixture contains failing tests by design, so the run exits non-zero;
  # swallow it (we only care that --report-tap produced a valid TAP file).
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-tap "$report" "$test_file" >/dev/null 2>&1 || true

  assert_file_exists "$report"
  assert_file_contains "$report" "TAP version 13"
  assert_file_contains "$report" "1.."
  assert_file_contains "$report" "ok "
  assert_file_contains "$report" "not ok "

  rm "$report"
}

function provide_multiline_tap_modes() {
  bashunit::data_set --no-parallel
  bashunit::data_set --parallel
}

# @data_provider provide_multiline_tap_modes
function test_tap_report_keeps_a_multiline_title_on_one_result_line() {
  local dir fixture report
  dir="$(bashunit::temp_dir)"
  fixture="$dir/multiline_test.sh"
  report="$dir/report.tap"
  printf 'function %s() { bashunit::set_test_title "line one\nline two"; assert_true true; }\n' \
    test_multiline_title >"$fixture"
  ./bashunit "$1" --skip-env-file --report-tap "$report" "$fixture" >/dev/null 2>&1
  assert_file_contains "$report" 'ok 1 - line one line two'
  assert_same 3 "$(wc -l <"$report" | tr -d ' ')"
}
