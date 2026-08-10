#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034 # Mock functions are invoked indirectly

function set_up() {
  _BASHUNIT_REPORTS_TEST_FILES=()
  _BASHUNIT_REPORTS_TEST_NAMES=()
  _BASHUNIT_REPORTS_TEST_STATUSES=()
  _BASHUNIT_REPORTS_TEST_DURATIONS=()
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=()
  _BASHUNIT_REPORTS_TEST_FAILURES=()
  _BASHUNIT_REPORTS_TEST_LINES=()
  _BASHUNIT_REPORTS_TEST_RETRIES=()

  BASHUNIT_PROFILE=false
  BASHUNIT_COVERAGE=false
}

function test_md_escape_escapes_markdown_specials() {
  assert_same '\|a\* \_b\_ \`c\`' "$(bashunit::reports::__md_escape '|a* _b_ `c`')"
}

function test_md_escape_escapes_backslash_first() {
  assert_same '\\\*' "$(bashunit::reports::__md_escape '\*')"
}

function test_md_escape_strips_ansi() {
  assert_same 'red' "$(bashunit::reports::__md_escape "$(printf '\033[31mred\033[0m')")"
}

function test_reports_is_enabled_when_report_md_configured() {
  local out
  out="$(mktemp)"
  export BASHUNIT_REPORT_MD="$out"
  assert_successful_code "$(bashunit::reports::is_enabled && echo ok)"
  unset BASHUNIT_REPORT_MD
  rm -f "$out"
}

function test_generate_report_md_writes_failed_verdict_and_counts() {
  local out
  out="$(mktemp)"
  set_up_md_fixture
  mock_md_state

  bashunit::reports::generate_report_md "$out"

  local content
  content="$(cat "$out")"
  assert_contains "❌ 1 failed, 1 passed in 1.234s" "$content"
  assert_contains "| Passed | Failed | Skipped | Incomplete | Risky | Snapshot | Flaky |" "$content"
  assert_contains "| 1 | 1 | 0 | 0 | 0 | 0 | 0 |" "$content"
  rm -f "$out"
}

function test_generate_report_md_passing_run_omits_failures_section() {
  local out
  out="$(mktemp)"
  _BASHUNIT_REPORTS_TEST_FILES=("tests/math_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("")
  _BASHUNIT_REPORTS_TEST_LINES=("10")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0")
  mock_md_state_all_passing

  bashunit::reports::generate_report_md "$out"

  local content
  content="$(cat "$out")"
  assert_contains "✅ 1 passed in 1.234s" "$content"
  assert_not_contains "Failures" "$content"
  rm -f "$out"
}

function test_generate_report_md_strips_ansi_and_fences_failure() {
  local out
  out="$(mktemp)"
  set_up_md_fixture
  mock_md_state

  bashunit::reports::generate_report_md "$out"

  local content
  content="$(cat "$out")"
  assert_contains '```' "$content"
  assert_contains 'Expected "a" but got "b"' "$content"
  assert_not_contains "$(printf '\033')" "$content"
  rm -f "$out"
}

function test_generate_report_md_escapes_test_name_in_failures() {
  local out
  out="$(mktemp)"
  set_up_md_fixture
  mock_md_state

  bashunit::reports::generate_report_md "$out"

  local content
  content="$(cat "$out")"
  assert_contains 'it \|divides\* \`fast\`' "$content"
  assert_contains "tests/math_test.sh:20" "$content"
  rm -f "$out"
}

function test_append_github_step_summary_appends_not_truncates() {
  local out
  out="$(mktemp)"
  echo "previous step content" >"$out"
  set_up_md_fixture
  mock_md_state

  bashunit::reports::append_github_step_summary "$out"

  local content
  content="$(cat "$out")"
  assert_contains "previous step content" "$content"
  assert_contains "❌ 1 failed, 1 passed" "$content"
  rm -f "$out"
}

function test_slowest_tests_section_only_with_profile() {
  local out
  out="$(mktemp)"
  set_up_md_fixture
  mock_md_state

  bashunit::reports::generate_report_md "$out"
  assert_not_contains "Slowest tests" "$(cat "$out")"

  BASHUNIT_PROFILE=true
  bashunit::reports::generate_report_md "$out"

  local content
  content="$(cat "$out")"
  assert_contains "Slowest tests" "$content"
  # Sorted by duration descending: the 5ms test outranks the 3ms one.
  assert_matches "5 .*it adds" "$content"
  rm -f "$out"
}

function test_coverage_line_only_when_coverage_ran() {
  local out
  out="$(mktemp)"
  set_up_md_fixture
  mock_md_state
  function bashunit::coverage::get_percentage() { echo "85"; }

  bashunit::reports::generate_report_md "$out"
  assert_not_contains "Coverage" "$(cat "$out")"

  BASHUNIT_COVERAGE=true
  bashunit::reports::generate_report_md "$out"
  assert_contains "**Coverage:** 85%" "$(cat "$out")"
  rm -f "$out"
}

# One passed and one failed test; the failed one carries an ANSI-colored,
# multi-line message and a Markdown-hostile name.
function set_up_md_fixture() {
  _BASHUNIT_REPORTS_TEST_FILES=("tests/math_test.sh" "tests/math_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds" 'it |divides* `fast`')
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed" "failed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5" "3")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1" "1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("" "$(printf '\033[31mExpected "a" but got "b"\033[0m\nsecond line')")
  _BASHUNIT_REPORTS_TEST_LINES=("10" "20")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0" "0")
}

function mock_md_state() {
  function bashunit::state::get_tests_passed() { echo "1"; }
  function bashunit::state::get_tests_failed() { echo "1"; }
  function bashunit::state::get_tests_skipped() { echo "0"; }
  function bashunit::state::get_tests_incomplete() { echo "0"; }
  function bashunit::state::get_tests_risky() { echo "0"; }
  function bashunit::state::get_tests_snapshot() { echo "0"; }
  function bashunit::state::get_tests_flaky() { echo "0"; }
  function bashunit::clock::total_runtime_in_milliseconds() { echo "1234"; }
}

function mock_md_state_all_passing() {
  mock_md_state
  function bashunit::state::get_tests_passed() { echo "1"; }
  function bashunit::state::get_tests_failed() { echo "0"; }
}
