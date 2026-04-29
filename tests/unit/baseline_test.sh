#!/usr/bin/env bash

# shellcheck disable=SC2034,SC2329

function set_up_before_script() {
  _TEMP_OUTPUT_FILE=""
}

function set_up() {
  _BASHUNIT_REPORTS_TEST_FILES=()
  _BASHUNIT_REPORTS_TEST_NAMES=()
  _BASHUNIT_REPORTS_TEST_STATUSES=()
  _BASHUNIT_REPORTS_TEST_DURATIONS=()
  _BASHUNIT_REPORTS_TEST_ASSERTIONS=()
  _BASHUNIT_REPORTS_TEST_FAILURES=()

  _BASHUNIT_BASELINE_FILES=()
  _BASHUNIT_BASELINE_NAMES=()
  _BASHUNIT_BASELINE_STATUSES=()

  _TEMP_OUTPUT_FILE=$(mktemp)
}

function tear_down() {
  [ -n "$_TEMP_OUTPUT_FILE" ] && [ -f "$_TEMP_OUTPUT_FILE" ] && rm -f "$_TEMP_OUTPUT_FILE"
}

# === generate ===

function test_generate_writes_xml_header_and_root() {
  bashunit::baseline::generate "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<?xml version="1.0" encoding="UTF-8"?>' "$content"
  assert_contains '<baseline version="1.0">' "$content"
  assert_contains '</baseline>' "$content"
}

function test_generate_includes_failed_test_entry() {
  _BASHUNIT_REPORTS_TEST_FILES=("tests/foo_test.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("test_should_x")
  _BASHUNIT_REPORTS_TEST_STATUSES=("failed")

  bashunit::baseline::generate "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<test file="tests/foo_test.sh" name="test_should_x" status="failed"/>' "$content"
}

function test_generate_includes_risky_and_incomplete_entries() {
  _BASHUNIT_REPORTS_TEST_FILES=("a.sh" "b.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("test_risky" "test_incomplete")
  _BASHUNIT_REPORTS_TEST_STATUSES=("risky" "incomplete")

  bashunit::baseline::generate "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains 'name="test_risky" status="risky"' "$content"
  assert_contains 'name="test_incomplete" status="incomplete"' "$content"
}

function test_generate_excludes_passed_and_skipped_tests() {
  _BASHUNIT_REPORTS_TEST_FILES=("a.sh" "b.sh")
  _BASHUNIT_REPORTS_TEST_NAMES=("test_passed" "test_skipped")
  _BASHUNIT_REPORTS_TEST_STATUSES=("passed" "skipped")

  bashunit::baseline::generate "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_not_contains 'test_passed' "$content"
  assert_not_contains 'test_skipped' "$content"
}

function test_generate_xml_escapes_special_chars_in_attributes() {
  _BASHUNIT_REPORTS_TEST_FILES=('tests/foo & "bar".sh')
  _BASHUNIT_REPORTS_TEST_NAMES=('test_<x>_&_y')
  _BASHUNIT_REPORTS_TEST_STATUSES=("failed")

  bashunit::baseline::generate "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '&amp;' "$content"
  assert_contains '&lt;' "$content"
  assert_contains '&gt;' "$content"
  assert_contains '&quot;' "$content"
}

# === load ===

function test_load_populates_baseline_arrays() {
  cat >"$_TEMP_OUTPUT_FILE" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<baseline version="1.0">
  <test file="tests/foo_test.sh" name="test_should_x" status="failed"/>
  <test file="tests/bar_test.sh" name="test_risky_one" status="risky"/>
</baseline>
XML

  bashunit::baseline::load "$_TEMP_OUTPUT_FILE"

  assert_same "2" "${#_BASHUNIT_BASELINE_FILES[@]}"
  assert_same "tests/foo_test.sh" "${_BASHUNIT_BASELINE_FILES[0]}"
  assert_same "test_should_x" "${_BASHUNIT_BASELINE_NAMES[0]}"
  assert_same "failed" "${_BASHUNIT_BASELINE_STATUSES[0]}"
  assert_same "tests/bar_test.sh" "${_BASHUNIT_BASELINE_FILES[1]}"
  assert_same "test_risky_one" "${_BASHUNIT_BASELINE_NAMES[1]}"
  assert_same "risky" "${_BASHUNIT_BASELINE_STATUSES[1]}"
}

function test_load_decodes_xml_entities() {
  cat >"$_TEMP_OUTPUT_FILE" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<baseline version="1.0">
  <test file="a &amp; b.sh" name="test_&lt;x&gt;_&amp;_&quot;y&quot;" status="failed"/>
</baseline>
XML

  bashunit::baseline::load "$_TEMP_OUTPUT_FILE"

  assert_same 'a & b.sh' "${_BASHUNIT_BASELINE_FILES[0]}"
  assert_same 'test_<x>_&_"y"' "${_BASHUNIT_BASELINE_NAMES[0]}"
}

function test_load_returns_error_for_missing_file() {
  local rc=0
  bashunit::baseline::load "/nonexistent/baseline.xml" 2>/dev/null || rc=$?

  assert_not_equals "0" "$rc"
}

# === contains ===

function test_contains_returns_true_for_matching_entry() {
  _BASHUNIT_BASELINE_FILES=("tests/foo_test.sh")
  _BASHUNIT_BASELINE_NAMES=("test_should_x")
  _BASHUNIT_BASELINE_STATUSES=("failed")

  assert_successful_code "$(bashunit::baseline::contains "tests/foo_test.sh" "test_should_x" "failed" && echo $?)"
}

function test_contains_returns_false_when_no_match() {
  _BASHUNIT_BASELINE_FILES=("tests/foo_test.sh")
  _BASHUNIT_BASELINE_NAMES=("test_should_x")
  _BASHUNIT_BASELINE_STATUSES=("failed")

  local rc=0
  bashunit::baseline::contains "tests/foo_test.sh" "test_other" "failed" || rc=$?

  assert_not_equals "0" "$rc"
}

function test_contains_returns_false_when_status_differs() {
  _BASHUNIT_BASELINE_FILES=("tests/foo_test.sh")
  _BASHUNIT_BASELINE_NAMES=("test_should_x")
  _BASHUNIT_BASELINE_STATUSES=("failed")

  local rc=0
  bashunit::baseline::contains "tests/foo_test.sh" "test_should_x" "risky" || rc=$?

  assert_not_equals "0" "$rc"
}

function test_contains_returns_false_for_empty_baseline() {
  _BASHUNIT_BASELINE_FILES=()
  _BASHUNIT_BASELINE_NAMES=()
  _BASHUNIT_BASELINE_STATUSES=()

  local rc=0
  bashunit::baseline::contains "tests/foo_test.sh" "test_should_x" "failed" || rc=$?

  assert_not_equals "0" "$rc"
}
