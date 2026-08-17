#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_BASHUNIT_LOG_JUNIT="tests/acceptance/fixtures/.env.log_junit"
}

function test_bashunit_when_log_junit_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --log-junit custom.xml "$test_file")"
  assert_file_exists custom.xml
  rm custom.xml
}

function test_bashunit_when_log_junit_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_BASHUNIT_LOG_JUNIT" "$test_file")"
  assert_file_exists log-junit.xml
  rm log-junit.xml
}

function test_junit_carries_classname_suites_and_captured_output() {
  local fixture=tests/acceptance/fixtures/test_bashunit_junit_shape.sh
  local report
  report="$(bashunit::temp_file)"

  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --log-junit "$report" "$fixture" >/dev/null 2>&1 || true

  local content
  content="$(cat "$report")"
  assert_contains "<testsuite name=\"$fixture\" tests=\"2\" failures=\"1\"" "$content"
  assert_contains 'classname="tests.acceptance.fixtures.test_bashunit_junit_shape"' "$content"
  assert_contains '<system-out>hello from the test body</system-out>' "$content"
  assert_contains 'message="Expected &apos;expected junit value&apos;"' "$content"
}

# Regression guard for #1004: the rows are spooled by the workers and replayed
# in the parent, so the new columns must survive the fork boundary too.
function test_junit_captured_output_survives_parallel() {
  local fixture=tests/acceptance/fixtures/test_bashunit_junit_shape.sh
  local report
  report="$(bashunit::temp_file)"

  ./bashunit --parallel --env "$TEST_ENV_FILE" --log-junit "$report" "$fixture" >/dev/null 2>&1 || true

  local content
  content="$(cat "$report")"
  assert_contains '<system-out>hello from the test body</system-out>' "$content"
  assert_contains 'classname="tests.acceptance.fixtures.test_bashunit_junit_shape"' "$content"
}

function test_bashunit_report_junit_is_alias_of_log_junit() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh
  local report=report-junit-alias.xml

  # The fixture contains failing tests by design, so the run exits non-zero;
  # swallow it (we only care that --report-junit produced the file).
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-junit "$report" "$test_file" >/dev/null 2>&1 || true
  assert_file_exists "$report"
  assert_file_contains "$report" "<testsuite"
  rm "$report"
}

# __xml_escape is applied to the test name and the failure message, but the
# path-derived attributes -- testsuite name=, testcase classname= and file= --
# were interpolated raw. A path holding `"` closes the attribute early and the
# document stops parsing; `&` and `<` do the same. Same shape as #1307 and
# #1311: the escaper exists, it just was not reaching every site.
function test_junit_escapes_a_quote_in_the_file_path() {
  local dir
  dir="$(bashunit::temp_dir junit_quote_path)"
  printf 'function test_ok() { assert_true true; }\n' >"$dir/say \"hi\"_test.sh"

  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --report-junit "$dir/r.xml" "$dir/say \"hi\"_test.sh" >/dev/null 2>&1 || true

  assert_file_exists "$dir/r.xml"
  local content
  content="$(cat "$dir/r.xml")"
  # The raw quote must not survive inside an attribute value.
  assert_not_contains 'name="tests/say "hi"' "$content"
  assert_contains '&quot;hi&quot;' "$content"
}
