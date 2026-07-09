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
