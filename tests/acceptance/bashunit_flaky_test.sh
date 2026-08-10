#!/usr/bin/env bash

# A test that only passed after a retry is a distinct outcome: it passed, so the
# exit code stays 0, but the run has to say so or CI cannot triage flakiness.
# Reuses the deterministic retry fixture (a counter file survives the attempts).

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_retry.sh"
}

function set_up() {
  COUNTER_FILE="$(mktemp)"
  export BASHUNIT_RETRY_FIXTURE_COUNTER="$COUNTER_FILE"
  export BASHUNIT_RETRY_FIXTURE_PASS_ON=2
  printf '0' >"$COUNTER_FILE"
  REPORT_DIR="$(bashunit::temp_dir flaky_reports)"
}

function tear_down() {
  rm -f "$COUNTER_FILE"
  unset BASHUNIT_RETRY_FIXTURE_COUNTER BASHUNIT_RETRY_FIXTURE_PASS_ON
}

function test_a_test_that_only_passed_on_retry_is_counted_as_flaky() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky "$FIXTURE")"

  assert_contains "1 passed, 1 flaky, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_a_flaky_test_still_exits_zero_by_default() {
  local ec=0
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky "$FIXTURE" >/dev/null 2>&1 || ec=$?

  assert_same "0" "$ec"
}

function test_fail_on_flaky_turns_a_flaky_run_red() {
  local ec=0
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --fail-on-flaky --filter test_a_flaky "$FIXTURE" >/dev/null 2>&1 || ec=$?

  assert_general_error "" "" "$ec"
}

function test_a_clean_run_reports_no_flaky_count() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_b_always "$FIXTURE")"

  assert_contains "1 passed, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
  assert_not_contains "flaky" "$output"
}

function test_without_retries_a_failing_test_is_never_flaky() {
  local output
  output="$(./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 0 --filter test_a_flaky "$FIXTURE")" || true

  assert_contains "1 failed" "$output"
  # Not a bare "flaky": the fixture's own function name contains the word.
  assert_not_contains "1 flaky" "$output"
}

function test_flaky_counters_survive_parallel_aggregation() {
  local output
  output="$(./bashunit --parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky "$FIXTURE")"

  assert_contains "1 passed, 1 flaky, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_junit_reports_a_flaky_failure_carrying_the_first_attempt() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky --report-junit "$REPORT_DIR/report.xml" "$FIXTURE" >/dev/null 2>&1

  local report
  report="$(cat "$REPORT_DIR/report.xml")"

  assert_contains "<flakyFailure" "$report"
  assert_contains "failed-on-attempt-1" "$report"
  # Flaky is a pass, so it must not inflate the failure count.
  assert_contains 'failures="0"' "$report"
}

function test_tap_marks_a_flaky_test_as_a_todo() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky --report-tap "$REPORT_DIR/report.tap" "$FIXTURE" >/dev/null 2>&1

  local report
  report="$(cat "$REPORT_DIR/report.tap")"

  assert_contains "ok 1 - " "$report"
  assert_contains "# TODO flaky (retried 1/1)" "$report"
}

function test_json_carries_the_flaky_status_the_retries_and_the_first_failure() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky --report-json "$REPORT_DIR/report.json" "$FIXTURE" >/dev/null 2>&1

  local report
  report="$(cat "$REPORT_DIR/report.json")"

  assert_contains '"status": "flaky"' "$report"
  assert_contains '"retries": 1' "$report"
  assert_contains "failed-on-attempt-1" "$report"
  assert_contains '"flaky": 1' "$report"
}

function test_html_marks_the_flaky_row() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky --report-html "$REPORT_DIR/report.html" "$FIXTURE" >/dev/null 2>&1

  assert_contains "flaky" "$(cat "$REPORT_DIR/report.html")"
}

function test_github_actions_annotates_a_flaky_test_as_a_warning() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --retry 1 --filter test_a_flaky --log-gha "$REPORT_DIR/gha.log" "$FIXTURE" >/dev/null 2>&1

  assert_contains "::warning" "$(cat "$REPORT_DIR/gha.log")"
}
