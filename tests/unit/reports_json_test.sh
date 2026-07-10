#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

_JQ_AVAILABLE=false
if command -v jq >/dev/null 2>&1; then
  _JQ_AVAILABLE=true
fi

function test_json_escape_escapes_quotes_and_backslashes() {
  assert_same 'a\"b\\c' "$(bashunit::reports::__json_escape 'a"b\c')"
}

function test_json_escape_escapes_newlines_and_tabs() {
  assert_same 'a\tb\nc' "$(bashunit::reports::__json_escape "$(printf 'a\tb\nc')")"
}

function test_generate_report_json_summary_counts() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local out
  out="$(mktemp)"
  set_up_report_fixture
  bashunit::reports::generate_report_json "$out"

  assert_same "2" "$(jq '.summary.total' "$out")"
  assert_same "1" "$(jq '.summary.passed' "$out")"
  assert_same "1" "$(jq '.summary.failed' "$out")"
  rm -f "$out"
}

function test_generate_report_json_is_valid_and_escapes_messages() {
  if [ "$_JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local out
  out="$(mktemp)"
  set_up_report_fixture
  bashunit::reports::generate_report_json "$out"

  # jq parsing succeeds only if the embedded quote AND newline were escaped
  # correctly; asserting the quote substring avoids a Windows CRLF round-trip.
  assert_successful_code "$(jq empty "$out" 2>&1)"
  assert_same 'failed' "$(jq -r '.tests[1].status' "$out")"
  assert_contains 'say "hi"' "$(jq -r '.tests[1].message' "$out")"
  rm -f "$out"
}

# Populates the reports arrays with one passed and one failed test; the failed
# message contains a quote and a newline to exercise escaping.
function set_up_report_fixture() {
  _BASHUNIT_REPORTS_TEST_FILES=("tests/math_test.sh" "tests/math_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds" "it divides")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed" "failed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5" "3")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1" "1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("" "$(printf 'say "hi"\nnext')")
  _BASHUNIT_REPORTS_TEST_LINES=("10" "20")
}
