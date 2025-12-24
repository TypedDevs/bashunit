#!/usr/bin/env bash

# shellcheck disable=SC2034,SC2329 # Mock functions are invoked indirectly

function set_up_before_script() {
  _TEMP_OUTPUT_FILE=""
}

function set_up() {
  # Reset all report arrays before each test
  _BASHUNIT_REPORTS_TEST_FILES=()
  _BASHUNIT_REPORTS_TEST_NAMES=()
  _BASHUNIT_REPORTS_TEST_STATUSES=()
  _BASHUNIT_REPORTS_TEST_DURATIONS=()
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=()

  # Unset report env vars by default
  unset BASHUNIT_LOG_JUNIT
  unset BASHUNIT_REPORT_HTML

  # Create temp file for output tests
  _TEMP_OUTPUT_FILE=$(mktemp)
}

function tear_down() {
  # Clean up temp files
  [[ -n "$_TEMP_OUTPUT_FILE" && -f "$_TEMP_OUTPUT_FILE" ]] && rm -f "$_TEMP_OUTPUT_FILE"

  # Restore env vars
  unset BASHUNIT_LOG_JUNIT
  unset BASHUNIT_REPORT_HTML
}

# Mock functions for report generation tests
function _mock_state_functions() {
  function bashunit::state::get_tests_passed() { echo "5"; }
  function bashunit::state::get_tests_skipped() { echo "1"; }
  function bashunit::state::get_tests_incomplete() { echo "2"; }
  function bashunit::state::get_tests_snapshot() { echo "1"; }
  function bashunit::state::get_tests_failed() { echo "1"; }
  function bashunit::clock::total_runtime_in_milliseconds() { echo "1234"; }
}

# === Existing test ===

function test_add_test_skips_tracking_without_report_output() {
  local before after

  before=${#_BASHUNIT_REPORTS_TEST_NAMES[@]}

  bashunit::reports::add_test "file.sh" "a test" 0 0 passed

  after=${#_BASHUNIT_REPORTS_TEST_NAMES[@]}

  assert_same "$before" "$after"
}

# === Wrapper function tests ===

function test_add_test_snapshot_sets_snapshot_status() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test_snapshot "test.sh" "my_test" "100" "2"

  assert_same "snapshot" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
}

function test_add_test_incomplete_sets_incomplete_status() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test_incomplete "test.sh" "my_test" "100" "2"

  assert_same "incomplete" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
}

function test_add_test_skipped_sets_skipped_status() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test_skipped "test.sh" "my_test" "100" "2"

  assert_same "skipped" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
}

function test_add_test_passed_sets_passed_status() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test_passed "test.sh" "my_test" "100" "2"

  assert_same "passed" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
}

function test_add_test_failed_sets_failed_status() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test_failed "test.sh" "my_test" "100" "2"

  assert_same "failed" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
}

# === Core add_test tests ===

function test_add_test_tracks_when_junit_enabled() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "file.sh" "test_name" "100" "3" "passed"

  assert_same "1" "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
}

function test_add_test_tracks_when_html_report_enabled() {
  BASHUNIT_REPORT_HTML="report.html"

  bashunit::reports::add_test "file.sh" "test_name" "100" "3" "passed"

  assert_same "1" "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
}

function test_add_test_populates_all_arrays() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "my_file.sh" "my_test_name" "250" "5" "failed"

  assert_same "my_file.sh" "${_BASHUNIT_REPORTS_TEST_FILES[0]}"
  assert_same "my_test_name" "${_BASHUNIT_REPORTS_TEST_NAMES[0]}"
  assert_same "failed" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
  assert_same "250" "${_BASHUNIT_REPORTS_TEST_DURATIONS[0]}"
  assert_same "5" "${_BASHUNIT_REPORTS_TEST_ASSERTIONS[0]}"
}

# === JUnit XML generation tests ===

function test_generate_junit_xml_creates_valid_xml_header() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<?xml version="1.0" encoding="UTF-8"?>' "$content"
  assert_contains '<testsuites>' "$content"
  assert_contains '</testsuites>' "$content"
}

function test_generate_junit_xml_includes_testsuite_attributes() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<testsuite name="bashunit"' "$content"
  assert_contains 'tests="1"' "$content"
  assert_contains 'passed="5"' "$content"
  assert_contains 'failures="1"' "$content"
  assert_contains 'time="1234"' "$content"
}

function test_generate_junit_xml_includes_testcase_elements() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "my_test.sh" "test_example" "500" "3" "passed"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<testcase file="my_test.sh"' "$content"
  assert_contains 'name="test_example"' "$content"
  assert_contains 'status="passed"' "$content"
  assert_contains 'assertions="3"' "$content"
  assert_contains 'time="500"' "$content"
}

# === HTML report generation tests ===

function test_generate_report_html_creates_valid_html_structure() {
  _mock_state_functions
  BASHUNIT_REPORT_HTML="report.html"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::generate_report_html "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<!DOCTYPE html>' "$content"
  assert_contains '<html lang="en">' "$content"
  assert_contains '</html>' "$content"
  assert_contains '<title>Test Report</title>' "$content"
}

function test_generate_report_html_includes_summary_table() {
  _mock_state_functions
  BASHUNIT_REPORT_HTML="report.html"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::generate_report_html "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<h1>Test Report</h1>' "$content"
  assert_contains '<th>Total Tests</th>' "$content"
  assert_contains '<th>Passed</th>' "$content"
  assert_contains '<th>Failed</th>' "$content"
  assert_contains '<td>5</td>' "$content"
}

function test_generate_report_html_groups_tests_by_file() {
  _mock_state_functions
  BASHUNIT_REPORT_HTML="report.html"

  bashunit::reports::add_test "file_a.sh" "test_one" "100" "2" "passed"
  bashunit::reports::add_test "file_b.sh" "test_two" "200" "3" "failed"
  bashunit::reports::generate_report_html "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<h2>File: file_a.sh</h2>' "$content"
  assert_contains '<h2>File: file_b.sh</h2>' "$content"
}

function test_generate_report_html_applies_status_css_classes() {
  _mock_state_functions
  BASHUNIT_REPORT_HTML="report.html"

  bashunit::reports::add_test "test.sh" "test_passed" "100" "2" "passed"
  bashunit::reports::add_test "test.sh" "test_failed" "100" "2" "failed"
  bashunit::reports::add_test "test.sh" "test_skipped" "100" "2" "skipped"
  bashunit::reports::generate_report_html "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<tr class="passed">' "$content"
  assert_contains '<tr class="failed">' "$content"
  assert_contains '<tr class="skipped">' "$content"
}
