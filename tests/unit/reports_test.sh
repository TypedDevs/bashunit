#!/usr/bin/env bash

# shellcheck disable=SC2034

function test_add_test_skips_tracking_without_report_output() {
  local tracked
  tracked=$(
    unset BASHUNIT_LOG_JUNIT
    unset BASHUNIT_REPORT_HTML

    reports::add_test "file.sh" "a test" 0 0 passed

    echo "${#_REPORTS_TEST_NAMES[@]}"
  )

  assert_same "0" "$tracked"
}
