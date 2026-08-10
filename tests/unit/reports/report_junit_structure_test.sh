#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034 # Mock functions are invoked indirectly

_XMLLINT_AVAILABLE=false
if command -v xmllint >/dev/null 2>&1; then
  _XMLLINT_AVAILABLE=true
fi

function set_up() {
  _BASHUNIT_REPORTS_TEST_FILES=()
  _BASHUNIT_REPORTS_TEST_NAMES=()
  _BASHUNIT_REPORTS_TEST_STATUSES=()
  _BASHUNIT_REPORTS_TEST_DURATIONS=()
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=()
  _BASHUNIT_REPORTS_TEST_FAILURES=()
  _BASHUNIT_REPORTS_TEST_LINES=()
  _BASHUNIT_REPORTS_TEST_RETRIES=()
  _BASHUNIT_REPORTS_TEST_OUTPUTS=()
}

function test_junit_groups_testcases_into_one_suite_per_file() {
  local out
  out="$(mktemp)"
  set_up_two_file_fixture

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  assert_contains '<testsuite name="tests/unit/a_test.sh"' "$content"
  assert_contains '<testsuite name="tests/unit/b_test.sh"' "$content"
  assert_not_contains '<testsuite name="bashunit"' "$content"
  rm -f "$out"
}

function test_junit_testcase_carries_classname_name_file_and_time() {
  local out
  out="$(mktemp)"
  _BASHUNIT_REPORTS_TEST_FILES=("tests/unit/assert/core_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it adds")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("1500")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("")
  _BASHUNIT_REPORTS_TEST_LINES=("10")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0")
  _BASHUNIT_REPORTS_TEST_OUTPUTS=("")

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  assert_contains 'classname="tests.unit.assert.core_test"' "$content"
  assert_contains 'name="it adds"' "$content"
  assert_contains 'file="tests/unit/assert/core_test.sh"' "$content"
  assert_contains 'time="1.500"' "$content"
  rm -f "$out"
}

function test_junit_failure_message_is_first_line_of_the_real_message() {
  local out
  out="$(mktemp)"
  set_up_two_file_fixture

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  assert_contains '<failure message="Expected 1 but got 2" type="AssertionFailed">' "$content"
  assert_contains 'second line detail</failure>' "$content"
  assert_not_contains 'message="Test failed"' "$content"
  rm -f "$out"
}

function test_junit_failure_message_skips_the_failed_banner_line() {
  local out
  out="$(mktemp)"
  _BASHUNIT_REPORTS_TEST_FILES=("tests/x_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it fails")
  _BASHUNIT_REPORTS_TEST_STATUSES=("failed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1")
  _BASHUNIT_REPORTS_TEST_FAILURES=("$(printf "✗ Failed: it fails\n    Expected 'a'\n    but got 'b'")")
  _BASHUNIT_REPORTS_TEST_LINES=("3")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0")
  _BASHUNIT_REPORTS_TEST_OUTPUTS=("")

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  # The banner repeats the name attribute; the next line carries the reason.
  assert_contains 'message="Expected &apos;a&apos;"' "$content"
  # The body still opens with the full message, banner included.
  assert_contains 'Failed: it fails' "$content"
  rm -f "$out"
}

function test_junit_system_out_present_only_when_the_test_printed_output() {
  local out
  out="$(mktemp)"
  set_up_two_file_fixture

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  assert_contains '<system-out>debug: setting up</system-out>' "$content"
  # Exactly one testcase printed output, so exactly one system-out element.
  assert_same "1" "$(grep -c '<system-out>' "$out" | tr -d ' ')"
  rm -f "$out"
}

function test_junit_per_suite_counts_and_aggregate_totals() {
  local out
  out="$(mktemp)"
  set_up_two_file_fixture

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  # Outer aggregate: 3 tests, 1 failure, 1 skipped.
  assert_contains '<testsuites name="bashunit" tests="3" failures="1" skipped="1" errors="0"' "$content"
  # Suite a: 2 tests, 1 failure. Suite b: 1 test, 1 skipped.
  assert_matches '<testsuite name="tests/unit/a_test.sh" tests="2" failures="1" skipped="0"' "$content"
  assert_matches '<testsuite name="tests/unit/b_test.sh" tests="1" failures="0" skipped="1"' "$content"
  rm -f "$out"
}

function test_junit_suites_carry_a_timestamp() {
  local out
  out="$(mktemp)"
  set_up_two_file_fixture

  bashunit::reports::generate_junit_xml "$out"

  assert_matches 'timestamp="[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"' "$(cat "$out")"
  rm -f "$out"
}

function test_junit_output_is_well_formed_xml() {
  if [ "$_XMLLINT_AVAILABLE" = false ]; then bashunit::skip "xmllint required"; return; fi
  local out
  out="$(mktemp)"
  set_up_two_file_fixture

  bashunit::reports::generate_junit_xml "$out"

  assert_successful_code "$(xmllint --noout "$out" 2>&1)"
  rm -f "$out"
}

function test_junit_escapes_xml_in_system_out_and_failure() {
  local out
  out="$(mktemp)"
  _BASHUNIT_REPORTS_TEST_FILES=("tests/x_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it escapes")
  _BASHUNIT_REPORTS_TEST_STATUSES=("failed")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("5")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1")
  _BASHUNIT_REPORTS_TEST_FAILURES=('a < b & "c"')
  _BASHUNIT_REPORTS_TEST_LINES=("3")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0")
  _BASHUNIT_REPORTS_TEST_OUTPUTS=('<tag> & "quoted"')

  bashunit::reports::generate_junit_xml "$out"

  local content
  content="$(cat "$out")"
  assert_contains 'a &lt; b &amp; &quot;c&quot;' "$content"
  assert_contains '<system-out>&lt;tag&gt; &amp; &quot;quoted&quot;</system-out>' "$content"
  rm -f "$out"
}

# Three tests across two files: a passing test with captured output and a
# multi-line failure in file a, a skipped test in file b.
function set_up_two_file_fixture() {
  _BASHUNIT_REPORTS_TEST_FILES=("tests/unit/a_test.sh" "tests/unit/a_test.sh" "tests/unit/b_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("it passes" "it fails" "it skips")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed" "failed" "skipped")
  _BASHUNIT_REPORTS_TEST_DURATIONS=("100" "200" "0")
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=("1" "1" "0")
  _BASHUNIT_REPORTS_TEST_FAILURES=("" "$(printf 'Expected 1 but got 2\nsecond line detail')" "")
  _BASHUNIT_REPORTS_TEST_LINES=("10" "20" "5")
  _BASHUNIT_REPORTS_TEST_RETRIES=("0" "0" "0")
  _BASHUNIT_REPORTS_TEST_OUTPUTS=("debug: setting up" "" "")
}
