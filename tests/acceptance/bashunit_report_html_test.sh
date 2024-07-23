#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_REPORT_HTML="tests/acceptance/fixtures/.env.report_html"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_when_report_html_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_report_html.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" --report-html custom.html "$test_file")"
  assert_file_exists custom.html
  rm custom.html
}

function test_bashunit_when_report_html_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_report_html.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_REPORT_HTML" "$test_file")"
  assert_file_exists report.html
  rm report.html
}
