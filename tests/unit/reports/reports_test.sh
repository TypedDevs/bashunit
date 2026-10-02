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
  _BASHUNIT_REPORTS_TEST_FAILURES=()
  _BASHUNIT_REPORTS_TEST_LINES=()
  _BASHUNIT_REPORTS_TEST_RETRIES=()
  _BASHUNIT_REPORTS_TEST_OUTPUTS=()
  _BASHUNIT_REPORTS_CURRENT_OUTPUT=""
  _BASHUNIT_TEST_LOCATION=""

  # Unset report env vars by default
  unset BASHUNIT_LOG_JUNIT
  unset BASHUNIT_REPORT_HTML
  unset BASHUNIT_LOG_GHA
  unset BASHUNIT_REPORT_TAP

  # These tests ask whether a *file* report was configured. Stdout annotations
  # and the Markdown step summary are two further reasons to collect rows, and
  # both switch themselves on inside GitHub Actions, so pin them off to keep the
  # answer independent of the ambient CI environment.
  export BASHUNIT_GHA_ANNOTATIONS=never
  unset GITHUB_STEP_SUMMARY
  unset BASHUNIT_REPORT_MD

  # Create temp file for output tests
  _TEMP_OUTPUT_FILE=$(mktemp)
}

function tear_down() {
  # Clean up temp files
  [[ -n "$_TEMP_OUTPUT_FILE" && -f "$_TEMP_OUTPUT_FILE" ]] && rm -f "$_TEMP_OUTPUT_FILE"

  # Restore env vars
  unset BASHUNIT_LOG_JUNIT
  unset BASHUNIT_REPORT_HTML
  unset BASHUNIT_LOG_GHA
  unset BASHUNIT_GHA_ANNOTATIONS
  unset BASHUNIT_REPORT_MD
}

function _reports_is_enabled_state() {
  local state="disabled"
  if bashunit::reports::is_enabled; then
    state="enabled"
  fi
  echo "$state"
}

function test_reports_is_enabled_false_when_no_report_configured() {
  unset BASHUNIT_LOG_JUNIT BASHUNIT_REPORT_HTML BASHUNIT_LOG_GHA BASHUNIT_REPORT_TAP BASHUNIT_REPORT_JSON
  assert_same "disabled" "$(_reports_is_enabled_state)"
}

function test_reports_is_enabled_true_when_a_report_is_configured() {
  unset BASHUNIT_LOG_JUNIT BASHUNIT_REPORT_HTML BASHUNIT_LOG_GHA BASHUNIT_REPORT_TAP BASHUNIT_REPORT_JSON
  export BASHUNIT_REPORT_JSON="$_TEMP_OUTPUT_FILE"
  local state
  state="$(_reports_is_enabled_state)"
  unset BASHUNIT_REPORT_JSON
  assert_same "enabled" "$state"
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

# === No-report-output short circuit ===

function test_add_test_skips_tracking_without_report_output() {
  local before after

  before=${#_BASHUNIT_REPORTS_TEST_NAMES[@]}

  bashunit::reports::add_test "file.sh" "a test" 0 0 passed

  after=${#_BASHUNIT_REPORTS_TEST_NAMES[@]}

  assert_same "$before" "$after"
}

function test_parallel_spool_roundtrips_concurrent_arbitrary_fields() {
  local dir
  dir="$(bashunit::temp_dir)"
  local REPORTS_OUTPUT_PATH="$dir/records"
  local BASHUNIT_REPORT_JSON="$dir/out.json"
  local _BASHUNIT_PARALLEL_ENABLED=true
  local _BASHUNIT_REPORTS_FILE_ORDINAL=1
  local _BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL=0
  local _BASHUNIT_REPORTS_RECORD_SCOPE=control
  local file="a/'b\c"$'\t\n\037'"ü.sh"
  local name="test 'quoted'\\"$'\t\n\037'"名"
  local message="failure 'quoted'\\"$'\t\n\037'"é"$'\n\n'
  local output="output 'quoted'\\"$'\t\n\037'"雪"$'\n\n'
  local i j n matches
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    (
      _BASHUNIT_REPORTS_RECORD_SCOPE=worker
      _BASHUNIT_REPORTS_WORKER_RECORD_ORDINAL=0
      _BASHUNIT_RUNNER_RESULT_ORDINAL=$i
      _BASHUNIT_TEST_LOCATION="$file $i:27"
      for j in 1 2 3 4; do
        bashunit::reports::set_current_test_output "$output$i/$j"$'\n\n'
        bashunit::reports::add_test_failed "$file $i" "$name $i/$j" "$i" "$j" "$message$i/$j"$'\n\n'
      done
    ) &
  done
  wait
  _BASHUNIT_RUNNER_RESULT_ORDINAL=13
  bashunit::reports::add_test_passed "" "" 0 0

  bashunit::reports::load_spooled

  assert_same 49 "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    for j in 1 2 3 4; do
      matches=0
      for n in "${!_BASHUNIT_REPORTS_TEST_NAMES[@]}"; do
        [ "${_BASHUNIT_REPORTS_TEST_NAMES[n]}" = "$name $i/$j" ] || continue
        matches=$((matches + 1))
        assert_same "$file $i" "${_BASHUNIT_REPORTS_TEST_FILES[n]}"
        assert_same failed "${_BASHUNIT_REPORTS_TEST_STATUSES[n]}"
        assert_same "$i" "${_BASHUNIT_REPORTS_TEST_DURATIONS[n]}"
        assert_same "$j" "${_BASHUNIT_REPORTS_TEST_ASSERTIONS[n]}"
        assert_same 27 "${_BASHUNIT_REPORTS_TEST_LINES[n]}"
        assert_same 0 "${_BASHUNIT_REPORTS_TEST_RETRIES[n]}"
        assert_same "$message$i/$j"$'\n\n' "${_BASHUNIT_REPORTS_TEST_FAILURES[n]}"
        assert_same "$output$i/$j"$'\n\n' "${_BASHUNIT_REPORTS_TEST_OUTPUTS[n]}"
      done
      assert_same 1 "$matches"
    done
  done
  assert_same "" "${_BASHUNIT_REPORTS_TEST_FILES[48]}"
  assert_same "" "${_BASHUNIT_REPORTS_TEST_NAMES[48]}"
  assert_same "" "${_BASHUNIT_REPORTS_TEST_FAILURES[48]}"
  assert_same "" "${_BASHUNIT_REPORTS_TEST_OUTPUTS[48]}"

  bashunit::reports::load_spooled
  assert_same 49 "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
}

function test_parallel_spool_keeps_control_rows_and_large_output() {
  local dir
  dir="$(bashunit::temp_dir)"
  local REPORTS_OUTPUT_PATH="$dir/records"
  local BASHUNIT_REPORT_JSON="$dir/out.json"
  local _BASHUNIT_PARALLEL_ENABLED=true
  local _BASHUNIT_REPORTS_FILE_ORDINAL=1
  local _BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL=0
  local _BASHUNIT_REPORTS_RECORD_SCOPE=control
  local _BASHUNIT_RUNNER_RESULT_ORDINAL=0
  local large=""
  local block="0123456789abcdef"
  local i
  for ((i = 0; i < 15; i++)); do
    block="$block$block"
  done
  large="$block"$'\n\n'

  bashunit::reports::add_test_failed "a/same.sh" "set_up_before_script" 0 0 "hook failure"
  _BASHUNIT_RUNNER_RESULT_ORDINAL=1
  bashunit::reports::add_test_failed "a/same.sh" "provider row" 0 0 "provider failure"
  _BASHUNIT_REPORTS_FILE_ORDINAL=2
  _BASHUNIT_RUNNER_RESULT_ORDINAL=0
  _BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL=0
  bashunit::reports::set_current_test_output "$large"
  bashunit::reports::add_test_passed "b/same.sh" "large output" 0 0

  bashunit::reports::load_spooled

  assert_same 3 "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
  assert_same "set_up_before_script" "${_BASHUNIT_REPORTS_TEST_NAMES[0]}"
  assert_same "provider row" "${_BASHUNIT_REPORTS_TEST_NAMES[1]}"
  assert_same "b/same.sh" "${_BASHUNIT_REPORTS_TEST_FILES[2]}"
  assert_same "$large" "${_BASHUNIT_REPORTS_TEST_OUTPUTS[2]}"
}

function test_parallel_spool_replays_publication_order_with_a_delayed_worker() {
  if bashunit::check_os::is_windows; then
    bashunit::skip "named pipes are unavailable under Git Bash" && return
  fi

  local dir
  dir="$(bashunit::temp_dir)"
  local REPORTS_OUTPUT_PATH="$dir/records"
  local BASHUNIT_REPORT_JSON="$dir/out.json"
  local _BASHUNIT_PARALLEL_ENABLED=true
  local _BASHUNIT_REPORTS_FILE_ORDINAL=1
  local _BASHUNIT_REPORTS_CONTROL_RECORD_ORDINAL=0
  local _BASHUNIT_REPORTS_RECORD_SCOPE=control
  mkfifo "$dir/release"
  (
    _BASHUNIT_REPORTS_RECORD_SCOPE=worker
    _BASHUNIT_RUNNER_RESULT_ORDINAL=1
    IFS= read -r release <"$dir/release"
    bashunit::reports::add_test_passed "a/same.sh" "delayed" 0 1
  ) &
  local delayed_pid=$!
  (
    _BASHUNIT_REPORTS_RECORD_SCOPE=worker
    _BASHUNIT_RUNNER_RESULT_ORDINAL=2
    bashunit::reports::add_test_passed "a/same.sh" "first published" 0 1
  ) &
  wait "$!"
  _BASHUNIT_REPORTS_FILE_ORDINAL=2
  _BASHUNIT_RUNNER_RESULT_ORDINAL=0
  bashunit::reports::add_test_failed "b/same.sh" "parent failure" 0 0 "hook failure"
  printf 'release\n' >"$dir/release"
  wait "$delayed_pid"

  bashunit::reports::load_spooled

  assert_same 3 "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
  assert_same "first published" "${_BASHUNIT_REPORTS_TEST_NAMES[0]}"
  assert_same "parent failure" "${_BASHUNIT_REPORTS_TEST_NAMES[1]}"
  assert_same delayed "${_BASHUNIT_REPORTS_TEST_NAMES[2]}"
}

function test_parallel_spool_preserves_open_file_descriptors() {
  local dir
  dir="$(bashunit::temp_dir)"
  local REPORTS_OUTPUT_PATH="$dir/records"
  local BASHUNIT_REPORT_JSON="$dir/out.json"
  local _BASHUNIT_PARALLEL_ENABLED=true
  local _BASHUNIT_REPORTS_RECORD_SCOPE=control
  local remaining=""
  printf 'caller input\n' >"$dir/input"
  bashunit::reports::add_test_passed "file.sh" "test" 0 1

  {
    bashunit::reports::load_spooled
    IFS= read -r remaining 2>/dev/null <&9 || true
  } 9<"$dir/input"

  assert_same "caller input" "$remaining"
}

function test_parallel_spool_skips_incomplete_records_and_sidecars() {
  local dir
  dir="$(bashunit::temp_dir)"
  local REPORTS_OUTPUT_PATH="$dir/records"
  local BASHUNIT_REPORT_JSON="$dir/out.json"
  local _BASHUNIT_PARALLEL_ENABLED=true
  local _BASHUNIT_REPORTS_RECORD_SCOPE=control
  local _BASHUNIT_RUNNER_RESULT_ORDINAL=4
  local truncated_token=0000000100000001000000001
  local missing_token=0000000100000002000000001
  local incomplete_token=0000000100000003000000001
  local truncated="$REPORTS_OUTPUT_PATH.$truncated_token.record"
  local missing="$REPORTS_OUTPUT_PATH.$missing_token.record"
  local incomplete="$REPORTS_OUTPUT_PATH.$incomplete_token.record"
  printf '%s\0' "file.sh" "truncated" >"$truncated"
  printf '%s\0' "file.sh" "missing" failed 0 0 "" 0 1 0 >"$missing"
  printf '%s\0' "file.sh" "incomplete" passed 0 1 "" 0 0 1 >"$incomplete"
  printf '%s' "unfinished output" >"$incomplete.output"
  printf '%s' "orphaned field_" >"$REPORTS_OUTPUT_PATH.orphan.record.failure"
  printf '%s\n' "$truncated_token" "$missing_token" "$incomplete_token" >"$REPORTS_OUTPUT_PATH"
  bashunit::reports::add_test_passed "file.sh" "complete" 0 1

  bashunit::reports::load_spooled 2>"$dir/warnings"

  assert_same 1 "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
  assert_same complete "${_BASHUNIT_REPORTS_TEST_NAMES[0]}"
  assert_file_contains "$dir/warnings" "incomplete report record $truncated"
  assert_file_contains "$dir/warnings" "missing report field $missing.failure"
  assert_file_contains "$dir/warnings" "incomplete report field $incomplete.output"
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

  bashunit::reports::add_test_failed "test.sh" "my_test" "100" "2" "some error"

  assert_same "failed" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
  assert_same "some error" "${_BASHUNIT_REPORTS_TEST_FAILURES[0]}"
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

function test_add_test_tracks_when_gha_log_enabled() {
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "file.sh" "test_name" "100" "3" "passed"

  assert_same "1" "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
}

function test_add_test_populates_all_arrays() {
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "my_file.sh" "my_test_name" "250" "5" "failed" "expected X got Y"

  assert_same "my_file.sh" "${_BASHUNIT_REPORTS_TEST_FILES[0]}"
  assert_same "my_test_name" "${_BASHUNIT_REPORTS_TEST_NAMES[0]}"
  assert_same "failed" "${_BASHUNIT_REPORTS_TEST_STATUSES[0]}"
  assert_same "250" "${_BASHUNIT_REPORTS_TEST_DURATIONS[0]}"
  assert_same "5" "${_BASHUNIT_REPORTS_TEST_ASSERTIONS[0]}"
  assert_same "expected X got Y" "${_BASHUNIT_REPORTS_TEST_FAILURES[0]}"
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
  assert_contains '<testsuites name="bashunit"' "$content"
  assert_contains '</testsuites>' "$content"
}

function test_generate_junit_xml_includes_testsuite_attributes() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  # One suite per test file; the counts derive from the recorded rows, not the
  # global state counters (#1016).
  assert_contains '<testsuite name="test.sh" tests="1" failures="0" skipped="0" errors="0"' "$content"
  assert_contains '<testsuites name="bashunit" tests="1" failures="0" skipped="0" errors="0"' "$content"
  assert_contains 'time="0.100"' "$content"
}

function test_generate_junit_xml_includes_testcase_elements() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "my_test.sh" "test_example" "500" "3" "passed"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<testcase classname="my_test" name="test_example"' "$content"
  assert_contains 'file="my_test.sh"' "$content"
  assert_contains 'time="0.500"' "$content"
  assert_not_contains 'status=' "$content"
  assert_not_contains 'assertions=' "$content"
}

function test_generate_junit_xml_passed_has_no_children() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_ok" "200" "1" "passed"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_not_contains '<failure' "$content"
  assert_not_contains '<skipped' "$content"
}

function test_generate_junit_xml_skipped_testcase() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_skip" "0" "0" "skipped"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<skipped/>' "$content"
  assert_not_contains '<failure' "$content"
}

function test_generate_junit_xml_incomplete_testcase() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_todo" "0" "0" "incomplete"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '<skipped message="Test incomplete"/>' "$content"
  assert_not_contains '<failure' "$content"
}

function test_generate_junit_xml_failure_message_carries_the_real_reason() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  local failure_msg="Assertion failed: expected 42 but got 0"
  bashunit::reports::add_test "test_fail.sh" "test_failure" "1000" "5" "failed" "$failure_msg"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains "<failure message=\"$failure_msg\" type=\"AssertionFailed\">" "$content"
  assert_contains "$failure_msg</failure>" "$content"
  assert_not_contains 'message="Test failed"' "$content"
}

function test_generate_junit_xml_failure_element_with_xml_escaping() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  local failure_msg='Expected "value1" & "value2" to be > other'
  bashunit::reports::add_test "test_fail.sh" "test_xml_escape" "500" "2" "failed" "$failure_msg"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  # Verify XML escaping is applied
  assert_contains 'Expected &quot;value1&quot; &amp; &quot;value2&quot; to be &gt; other</failure>' "$content"
}

function test_generate_junit_xml_strips_ansi_color_codes() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  local msg
  msg=$(printf 'expected \033[32mgreen\033[0m got \033[31mred\033[0m')
  bashunit::reports::add_test "test_fail.sh" "test_color" "100" "1" "failed" "$msg"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains 'expected green got red' "$content"
  assert_not_contains $'\033[' "$content"
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

# === GitHub Actions log generation tests ===

function test_generate_gha_log_emits_error_for_failed_test() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_fail" "100" "1" "failed" "expected 1 got 2"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '::error file=tests/foo_test.sh' "$content"
  assert_contains 'title=test_fail' "$content"
  assert_contains 'expected 1 got 2' "$content"
}

function test_generate_gha_log_emits_warning_for_risky_test() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_risky" "10" "0" "risky"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '::warning file=tests/foo_test.sh' "$content"
  assert_contains 'title=test_risky' "$content"
  assert_contains 'no assertions' "$content"
}

function test_generate_gha_log_emits_notice_for_incomplete_test() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_incomplete" "0" "0" "incomplete"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '::notice file=tests/foo_test.sh' "$content"
  assert_contains 'title=test_incomplete' "$content"
}

function test_generate_gha_log_skips_passed_test() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_ok" "100" "1" "passed"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_empty "$content"
}

function test_generate_gha_log_skips_skipped_test() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_skip" "0" "0" "skipped"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_empty "$content"
}

function test_generate_gha_log_includes_line_when_location_known() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"
  _BASHUNIT_TEST_LOCATION="tests/foo_test.sh:42"

  bashunit::reports::add_test "tests/foo_test.sh" "test_fail" "100" "1" "failed" "boom"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains '::error file=tests/foo_test.sh,line=42,title=test_fail' "$content"
}

function test_print_gha_annotations_failed_only_to_stdout() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_ok" "100" "1" "passed"
  bashunit::reports::add_test "tests/foo_test.sh" "test_bad" "100" "1" "failed" "boom"
  bashunit::reports::add_test "tests/foo_test.sh" "test_risky" "10" "0" "risky"

  local output
  output=$(bashunit::reports::print_gha_annotations failed-only)

  assert_contains '::error file=tests/foo_test.sh' "$output"
  assert_not_contains '::warning' "$output"
  assert_not_contains 'test_risky' "$output"
}

# The encoder writes %25 first so its own escapes stay literal, and on Bash 3.0
# that substitution silently did nothing: `${text//%/%25}` reads the `%` after
# `//` as the anchor-to-end form, so the replacement was appended and the text
# left unencoded (#1121).
function test_gha_annotation_percent_encodes_a_percent_sign() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  bashunit::reports::add_test "tests/foo_test.sh" "test_bad" "100" "1" "failed" \
    "coverage 80% -> 90%"

  local output
  output=$(bashunit::reports::print_gha_annotations failed-only)

  assert_contains "coverage 80%25 -> 90%25" "$output"
  assert_not_contains "80% " "$output"
}

function test_generate_gha_log_encodes_newlines_in_message() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  local msg
  msg=$(printf 'line one\nline two')
  bashunit::reports::add_test "tests/foo_test.sh" "test_multi" "100" "1" "failed" "$msg"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains 'line one%0Aline two' "$content"
  assert_not_contains 'line one
line two' "$content"
}

function test_generate_gha_log_strips_ansi_color_codes() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="gha.log"

  local msg
  msg=$(printf 'expected \033[32mgreen\033[0m got \033[31mred\033[0m')
  bashunit::reports::add_test "tests/foo_test.sh" "test_color" "100" "1" "failed" "$msg"
  bashunit::reports::generate_gha_log "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains 'expected green got red' "$content"
  assert_not_contains $'\033[' "$content"
}

function test_add_test_tracks_when_tap_report_enabled() {
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "file.sh" "test_name" "100" "3" "passed"

  assert_same "1" "${#_BASHUNIT_REPORTS_TEST_NAMES[@]}"
}

function test_generate_report_tap_creates_valid_header_and_plan() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::add_test "test.sh" "test_two" "100" "2" "passed"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains "TAP version 13" "$content"
  assert_contains "1..2" "$content"
}

function test_generate_report_tap_ok_for_passed_test() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "passed"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  assert_contains "ok 1 - test_one" "$(cat "$_TEMP_OUTPUT_FILE")"
}

# TAP reads an unescaped `#` as the start of a directive, so a passing test
# named "check # SKIP me" was reported as skipped and disappeared from the
# count on any dashboard consuming the file (#1119).
function test_generate_report_tap_escapes_a_hash_in_the_test_name() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "check # SKIP me" "100" "2" "passed"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  assert_contains 'ok 1 - check \# SKIP me' "$(cat "$_TEMP_OUTPUT_FILE")"
}

# A directive bashunit itself emits comes after the description and must stay
# readable as one.
function test_generate_report_tap_keeps_its_own_skip_directive_unescaped() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_one" "100" "2" "skipped"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  assert_contains "ok 1 - test_one # SKIP" "$(cat "$_TEMP_OUTPUT_FILE")"
}

function test_generate_report_tap_escapes_a_backslash_before_the_hash() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" 'path\to # thing' "100" "2" "passed"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  assert_contains 'ok 1 - path\\to \# thing' "$(cat "$_TEMP_OUTPUT_FILE")"
}

function test_generate_report_tap_not_ok_for_failed_test() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_bad" "100" "2" "failed" "expected 1 got 2"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains "not ok 1 - test_bad" "$content"
  assert_contains "expected 1 got 2" "$content"
}

function test_generate_report_tap_skip_directive_for_skipped_test() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_skip" "0" "0" "skipped"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  assert_contains "ok 1 - test_skip # SKIP" "$(cat "$_TEMP_OUTPUT_FILE")"
}

function test_generate_report_tap_todo_directive_for_incomplete_test() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_todo" "0" "0" "incomplete"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  assert_contains "ok 1 - test_todo # TODO" "$(cat "$_TEMP_OUTPUT_FILE")"
}

function test_generate_report_tap_strips_ansi_color_codes() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  local msg
  msg=$(printf 'expected \033[32mgreen\033[0m got \033[31mred\033[0m')
  bashunit::reports::add_test "test.sh" "test_color" "100" "1" "failed" "$msg"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains 'expected green got red' "$content"
  assert_not_contains $'\033[' "$content"
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

function test_generate_junit_xml_flaky_testcase() {
  _mock_state_functions
  BASHUNIT_LOG_JUNIT="report.xml"

  bashunit::reports::add_test "test.sh" "test_flaky" "10" "1" "flaky" "expected 1 got 2" "2"
  bashunit::reports::generate_junit_xml "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains "<flakyFailure" "$content"
  assert_contains "expected 1 got 2" "$content"
  # It passed, so it must not register as a failure.
  assert_not_contains "<failure" "$content"
}

function test_generate_report_tap_marks_a_flaky_test_as_todo() {
  _mock_state_functions
  BASHUNIT_REPORT_TAP="report.tap"

  bashunit::reports::add_test "test.sh" "test_flaky" "10" "1" "flaky" "boom" "2"
  bashunit::reports::generate_report_tap "$_TEMP_OUTPUT_FILE"

  local content
  content=$(cat "$_TEMP_OUTPUT_FILE")

  assert_contains "ok 1 - test_flaky # TODO flaky (retried 2/" "$content"
}

function test_gha_annotates_a_flaky_test_as_a_warning() {
  _mock_state_functions
  BASHUNIT_LOG_GHA="log-gha.txt"

  bashunit::reports::add_test "test.sh" "test_flaky" "10" "1" "flaky" "boom" "2"

  local content
  content=$(bashunit::reports::print_gha_annotations)

  assert_contains "::warning" "$content"
  assert_contains "only after 2 retries" "$content"
}
