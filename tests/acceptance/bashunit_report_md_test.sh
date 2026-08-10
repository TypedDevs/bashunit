#!/usr/bin/env bash

# Clearing _BASHUNIT_GHA_ANNOTATIONS_CLAIMED below is how a nested run says
# "pretend I am the top-level one": this suite is itself a bashunit run and has
# already claimed the job-owned outputs for its process tree, which is the very
# pollution the marker exists to prevent.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_report_md.sh"
}

function test_report_md_writes_verdict_counts_and_fenced_failure() {
  local report
  report="$(bashunit::temp_file)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-md "$report" "$FIXTURE" >/dev/null 2>&1 || true

  local content
  content="$(cat "$report")"
  assert_contains "1 failed, 1 passed in" "$content"
  assert_contains "| Passed | Failed | Skipped | Incomplete | Risky | Snapshot | Flaky |" "$content"
  assert_contains "| 1 | 1 | 0 | 0 | 0 | 0 | 0 |" "$content"
  assert_contains '```' "$content"
  assert_contains "expected value" "$content"
}

function test_report_md_escapes_markdown_specials_in_test_names() {
  local report
  report="$(bashunit::temp_file)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-md "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_contains 'md \|name\* \_with\_ \`specials\`' "$(cat "$report")"
}

function test_report_md_strips_ansi_from_failure_messages() {
  local report
  report="$(bashunit::temp_file)"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-md "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_not_contains "$(printf '\033')" "$(cat "$report")"
}

function test_report_md_is_populated_under_parallel() {
  local report
  report="$(bashunit::temp_file)"
  ./bashunit --parallel --env "$TEST_ENV_FILE" --report-md "$report" "$FIXTURE" >/dev/null 2>&1 || true

  local content
  content="$(cat "$report")"
  assert_contains "1 failed, 1 passed in" "$content"
  assert_contains "expected value" "$content"
}

function test_github_step_summary_is_appended_not_truncated() {
  local summary
  summary="$(bashunit::temp_file)"
  echo "earlier step content" >"$summary"

  _BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY="$summary" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1 || true

  local content
  content="$(cat "$summary")"
  assert_contains "earlier step content" "$content"
  assert_contains "1 failed, 1 passed in" "$content"
}

function test_explicit_report_md_wins_over_github_step_summary() {
  local report summary
  report="$(bashunit::temp_file)"
  summary="$(bashunit::temp_file)"
  echo "earlier step content" >"$summary"

  _BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY="$summary" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" --report-md "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_contains "1 failed, 1 passed in" "$(cat "$report")"
  assert_same "earlier step content" "$(cat "$summary")"
}

# The claim marker is left alone here, so this is a genuinely nested run. Under
# CI it inherits GITHUB_STEP_SUMMARY and must stay quiet, or every nested run
# in a suite would append its fixtures' results to the job summary.
function test_a_nested_run_never_writes_the_step_summary() {
  local summary
  summary="$(bashunit::temp_file)"
  echo "earlier step content" >"$summary"

  GITHUB_STEP_SUMMARY="$summary" \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1 || true

  assert_same "earlier step content" "$(cat "$summary")"
}

function test_report_md_is_not_written_without_the_flag() {
  local report
  report="$(bashunit::temp_file)"
  rm -f "$report"
  ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1 || true

  assert_file_not_exists "$report"
}

function test_an_unwritable_report_md_path_fails_fast() {
  local ec=0
  local output
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    --report-md /nonexistent-dir/report.md "$FIXTURE" 2>&1)" || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "BASHUNIT_REPORT_MD" "$output"
  assert_contains "cannot be written" "$output"
}

function test_report_md_appears_in_the_help() {
  assert_contains "--report-md" "$(./bashunit test --help)"
}
