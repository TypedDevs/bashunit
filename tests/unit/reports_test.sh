#!/usr/bin/env bash

# shellcheck disable=SC2034

function test_add_test_skips_tracking_without_report_output() {
  # Ensure `add_test` does not alter tracked tests when no report output is
  # requested. Capture the number of tracked tests before and after invoking the
  # function and assert that it remains unchanged. This avoids interference from
  # previous tests when the suite runs serially.
  local before after

  unset BASHUNIT_LOG_JUNIT
  unset BASHUNIT_REPORT_HTML

  before=${#_REPORTS_TEST_NAMES[@]}

  reports::add_test "file.sh" "a test" 0 0 passed

  after=${#_REPORTS_TEST_NAMES[@]}

  assert_same "$before" "$after"
}
