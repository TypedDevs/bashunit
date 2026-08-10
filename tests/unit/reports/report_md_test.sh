#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2329 # arrays and mocks are read indirectly

function set_up() {
  _BASHUNIT_REPORTS_TEST_FILES=()
  _BASHUNIT_REPORTS_TEST_NAMES=()
  _BASHUNIT_REPORTS_TEST_STATUSES=()
  _BASHUNIT_REPORTS_TEST_DURATIONS=()
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=()
  _BASHUNIT_REPORTS_TEST_FAILURES=()
  _BASHUNIT_REPORTS_TEST_LINES=()
  _BASHUNIT_REPORTS_TEST_RETRIES=()
  _MD_OUTPUT_FILE=$(mktemp)
}

function tear_down() {
  rm -f "$_MD_OUTPUT_FILE"
  unset BASHUNIT_REPORT_MD GITHUB_STEP_SUMMARY
}

function _mock_counters() {
  function bashunit::state::get_tests_passed() { echo "${_MOCK_PASSED:-0}"; }
  function bashunit::state::get_tests_failed() { echo "${_MOCK_FAILED:-0}"; }
  function bashunit::state::get_tests_skipped() { echo "0"; }
  function bashunit::state::get_tests_incomplete() { echo "0"; }
  function bashunit::state::get_tests_snapshot() { echo "0"; }
  function bashunit::state::get_tests_risky() { echo "0"; }
  function bashunit::state::get_tests_flaky() { echo "0"; }
  function bashunit::clock::total_runtime_in_milliseconds() { echo "1234"; }
}

function _green_run_fixture() {
  _mock_counters
  _MOCK_PASSED=2
  _MOCK_FAILED=0
  _BASHUNIT_REPORTS_TEST_FILES=("tests/math_test.sh" "tests/math_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds" "it divides")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed" "passed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5" "3")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1" "1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("" "")
  _BASHUNIT_REPORTS_TEST_LINES=("10" "20")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0" "0")
}

function _red_run_fixture() {
  _mock_counters
  _MOCK_PASSED=1
  _MOCK_FAILED=1
  _BASHUNIT_REPORTS_TEST_FILES=("tests/math_test.sh" "tests/math_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds" "it divides")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed" "failed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5" "3")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1" "1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("" "$(printf "\033[31mExpected '4'\033[0m\nbut got '5'")")
  _BASHUNIT_REPORTS_TEST_LINES=("10" "20")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0" "0")
}

function test_a_green_run_leads_with_a_passing_verdict() {
  _green_run_fixture
  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  assert_contains "2 passed" "$(cat "$_MD_OUTPUT_FILE")"
}

function test_a_green_run_has_no_failures_section() {
  _green_run_fixture
  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  assert_not_contains "## Failures" "$(cat "$_MD_OUTPUT_FILE")"
}

function test_a_red_run_leads_with_a_failing_verdict() {
  _red_run_fixture
  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  assert_contains "1 failed" "$(cat "$_MD_OUTPUT_FILE")"
}

function test_the_failure_message_is_fenced_and_ansi_free() {
  _red_run_fixture
  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  local content
  content=$(cat "$_MD_OUTPUT_FILE")

  assert_contains '```' "$content"
  assert_contains "but got '5'" "$content"
  assert_not_contains $'\e[' "$content"
}

function test_the_failure_names_its_file_and_line() {
  _red_run_fixture
  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  assert_contains "tests/math_test.sh:20" "$(cat "$_MD_OUTPUT_FILE")"
}

# A pipe would split a table cell, and the rest would render as emphasis or code.
function test_markdown_metacharacters_in_a_test_name_are_escaped() {
  _red_run_fixture
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds" 'a|b *c* _d_ `e`')

  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  local content
  content=$(cat "$_MD_OUTPUT_FILE")

  assert_contains 'a\|b \*c\* \_d\_ \`e\`' "$content"
}

function test_the_counts_table_reports_the_totals() {
  _green_run_fixture
  bashunit::reports::generate_report_md "$_MD_OUTPUT_FILE"

  local content
  content=$(cat "$_MD_OUTPUT_FILE")

  assert_contains "| Passed | 2 |" "$content"
  assert_contains "| Failed | 0 |" "$content"
}

# The step summary is shared with every other step in the job, so writing it
# would discard whatever ran before.
function test_the_step_summary_is_appended_not_truncated() {
  _green_run_fixture
  printf 'existing content\n' >"$_MD_OUTPUT_FILE"
  GITHUB_STEP_SUMMARY="$_MD_OUTPUT_FILE"

  bashunit::reports::append_step_summary

  local content
  content=$(cat "$_MD_OUTPUT_FILE")

  assert_contains "existing content" "$content"
  assert_contains "2 passed" "$content"
}
