#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_report_json.sh"
  JQ_AVAILABLE=false
  command -v jq >/dev/null 2>&1 && JQ_AVAILABLE=true
}

function test_report_json_writes_valid_json_with_correct_counts() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(mktemp)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-json "$report" "$FIXTURE" >/dev/null 2>&1

  assert_successful_code "$(jq empty "$report" 2>&1)"
  assert_same "2" "$(jq '.summary.total' "$report")"
  assert_same "1" "$(jq '.summary.passed' "$report")"
  assert_same "1" "$(jq '.summary.failed' "$report")"
  rm -f "$report"
}

function test_report_json_escapes_special_characters_in_messages() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(mktemp)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-json "$report" "$FIXTURE" >/dev/null 2>&1

  # A double quote inside the failure message must round-trip as valid JSON.
  local message
  message="$(jq -r '.tests[] | select(.status == "failed") | .message' "$report")"
  assert_contains 'a"b' "$message"
  rm -f "$report"
}

# Under --parallel the per-test rows are not aggregated (a pre-existing limit
# shared by all file reporters), but the output must still be valid JSON.
function test_report_json_is_valid_json_under_parallel() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(mktemp)"
  ./bashunit --parallel --env "$TEST_ENV_FILE" --report-json "$report" "$FIXTURE" >/dev/null 2>&1

  assert_successful_code "$(jq empty "$report" 2>&1)"
  rm -f "$report"
}

function test_report_json_is_not_written_without_the_flag() {
  local report
  report="$(mktemp)"
  rm -f "$report"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1

  assert_file_not_exists "$report"
}
