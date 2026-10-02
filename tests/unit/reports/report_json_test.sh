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

function test_json_escape_slot_matches_stdout_for_plain_and_control_values() {
  local value expected
  for value in '' 'plain/path.sh' 'a"b\c' $'tab\tcr\rline\nnext' \
    $'red\033[31mtext\033[0m' $'other\001control\177' '日本語 😀'; do
    expected="$(bashunit::reports::__json_escape "$value")"
    bashunit::reports::__json_escape_to_slot "$value"
    assert_same "$expected" "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
  done

  value="$(printf 'a%.0s' {1..10000})"$'\033[31m\t\n'
  expected="$(bashunit::reports::__json_escape "$value")"
  bashunit::reports::__json_escape_to_slot "$value"
  assert_same "$expected" "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
}

function test_json_escape_preserves_control_and_unicode_behavior() {
  bashunit::reports::__json_escape_to_slot $'tab\tcr\rline\nnext'
  assert_same 'tab\tcr\rline\nnext' "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"

  bashunit::reports::__json_escape_to_slot $'red\033[31mtext\033[0m\001\177'
  assert_same $'redtext\177' "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"

  bashunit::reports::__json_escape_to_slot '日本語 😀'
  assert_same '日本語 😀' "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
}

function test_report_json_plain_fields_do_not_run_strip_ansi_or_tr() {
  local out marker
  out="$(mktemp)"
  marker="$(mktemp)"
  (
    function bashunit::reports::__strip_ansi() {
      printf 'strip\n' >>"$marker"
      printf '%s' "$1"
    }
    function tr() {
      printf 'tr\n' >>"$marker"
      command tr "$@"
    }
    _BASHUNIT_REPORTS_TEST_FILES=("tests/plain.sh")
    _BASHUNIT_REPORTS_TEST_NAMES=("test_plain")
    _BASHUNIT_REPORTS_TEST_STATUSES=("passed")
    _BASHUNIT_REPORTS_TEST_DURATIONS=("5")
    _BASHUNIT_REPORTS_TEST_FAILURES=("")
    _BASHUNIT_REPORTS_TEST_RETRIES=("0")
    bashunit::reports::generate_report_json "$out"
    assert_same '0' "${#_BASHUNIT_REPORTS_JSON_ESCAPE_OUT}"
  )

  assert_same '' "$(cat "$marker")"
  assert_contains '"file": "tests/plain.sh", "name": "test_plain"' "$(cat "$out")"
  rm -f "$out" "$marker"
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
  assert_same 'say \"hi\"\nnext' "$_BASHUNIT_REPORTS_JSON_ESCAPE_OUT"
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
