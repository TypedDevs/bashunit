#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_report_json.sh"
  JQ_AVAILABLE=false
  # `|| true` so a jq-less box means "skip", not "hook failed" (#836)
  { command -v jq >/dev/null 2>&1 && JQ_AVAILABLE=true; } || true
}

function test_report_json_writes_valid_json_with_correct_counts() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(mktemp)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

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
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

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
  ./bashunit --parallel --env "$TEST_ENV_FILE" --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_successful_code "$(jq empty "$report" 2>&1)"
  rm -f "$report"
}

function test_report_json_is_not_written_without_the_flag() {
  local report
  report="$(mktemp)"
  rm -f "$report"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1 || true

  assert_file_not_exists "$report"
}

# A file-level hook failure is recorded by the parent, not by a worker. Under
# --parallel `add_test` spools the row *and* fills the parent's arrays, and
# `load_spooled` then replayed the spool into those same arrays -- so the report
# counted the failure twice and listed the test twice, while the console
# summary of the same run said one. The console was right.
function test_report_json_counts_a_hook_failure_once_under_parallel() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local dir report
  dir="$(bashunit::temp_dir dup_hook_report)"
  report="$dir/r.json"
  {
    printf 'function %s() { return 1; }\n' "set_up_before_script"
    printf 'function %s() { assert_true true; }\n' "test_never_runs"
  } >"$dir/hook_test.sh"

  ./bashunit --parallel --env "$TEST_ENV_FILE" --report-json "$report" \
    "$dir/hook_test.sh" >/dev/null 2>&1 || true

  assert_same "1" "$(jq '.summary.total' "$report")"
  assert_same "1" "$(jq '.summary.failed' "$report")"
  assert_same "1" "$(jq '.tests | length' "$report")"
}

# The same run's console summary and its report must agree.
function test_report_json_matches_the_console_summary_under_parallel() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local dir report output
  dir="$(bashunit::temp_dir report_console_parity)"
  report="$dir/r.json"
  {
    printf 'function %s() { assert_true true; }\n' "test_ok"
    printf 'function %s() { return 1; }\n' "tear_down_after_script"
  } >"$dir/td_test.sh"

  output=$(./bashunit --parallel --env "$TEST_ENV_FILE" --report-json "$report" \
    "$dir/td_test.sh" 2>&1) || true

  # Console says "1 passed, 1 failed, 2 total"; the report must say the same.
  assert_same "2" "$(jq '.summary.total' "$report")"
  assert_same "1" "$(jq '.summary.failed' "$report")"
  assert_contains "2 total" "$output"
}
