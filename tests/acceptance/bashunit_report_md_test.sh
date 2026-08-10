#!/usr/bin/env bash

# The Markdown summary targets the pull request page rather than a machine, so
# these cases assert what a reader would see, end to end.
#
# GITHUB_STEP_SUMMARY is inherited by every child process, so a nested run would
# append its own fixtures' results to the parent's job page. Clearing the
# outermost-run claim marker is how a test says "pretend I am the top-level run".

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="./tests/acceptance/fixtures/test_bashunit_when_log_junit.sh"
  PASSING_FIXTURE="./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh"
}

function set_up() {
  REPORT_DIR="$(bashunit::temp_dir report_md)"
}

function test_report_md_writes_a_markdown_summary() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --report-md "$REPORT_DIR/summary.md" "$FIXTURE" >/dev/null 2>&1 || true

  local content
  content="$(cat "$REPORT_DIR/summary.md")"

  assert_contains "## bashunit" "$content"
  assert_contains "| Result | Count |" "$content"
}

function test_a_failing_run_lists_the_failure_with_its_location() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --report-md "$REPORT_DIR/summary.md" "$FIXTURE" >/dev/null 2>&1 || true

  local content
  content="$(cat "$REPORT_DIR/summary.md")"

  assert_contains "## Failures" "$content"
  assert_contains "$FIXTURE:" "$content"
  assert_contains "but got" "$content"
}

function test_a_green_run_has_no_failures_section() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --report-md "$REPORT_DIR/summary.md" "$PASSING_FIXTURE" >/dev/null 2>&1

  local content
  content="$(cat "$REPORT_DIR/summary.md")"

  assert_contains "passed" "$content"
  assert_not_contains "## Failures" "$content"
}

function test_the_step_summary_is_appended_when_no_path_is_given() {
  local summary="$REPORT_DIR/step.md"
  printf 'previous step output\n' >"$summary"

  _BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY="$summary" \
    ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1 || true

  local content
  content="$(cat "$summary")"

  assert_contains "previous step output" "$content"
  assert_contains "## bashunit" "$content"
}

function test_an_explicit_path_wins_over_the_step_summary() {
  local summary="$REPORT_DIR/step.md"
  : >"$summary"

  _BASHUNIT_GHA_ANNOTATIONS_CLAIMED='' GITHUB_STEP_SUMMARY="$summary" \
    ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --report-md "$REPORT_DIR/summary.md" "$FIXTURE" >/dev/null 2>&1 || true

  assert_contains "## bashunit" "$(cat "$REPORT_DIR/summary.md")"
  assert_empty "$(cat "$summary")"
}

# A nested run must not append its own results to the parent's job page.
function test_a_nested_run_leaves_the_step_summary_alone() {
  local summary="$REPORT_DIR/step.md"
  : >"$summary"

  GITHUB_STEP_SUMMARY="$summary" ./bashunit --no-parallel --no-color \
    --env "$TEST_ENV_FILE" "$FIXTURE" >/dev/null 2>&1 || true

  assert_empty "$(cat "$summary")"
}

function test_the_report_is_populated_under_parallel() {
  ./bashunit --parallel --no-color --env "$TEST_ENV_FILE" \
    --report-md "$REPORT_DIR/summary.md" "$FIXTURE" >/dev/null 2>&1 || true

  assert_contains "## Failures" "$(cat "$REPORT_DIR/summary.md")"
}

# The summary's percentage is the console report's percentage. It used to be
# read before the hit records were finalized and, under --parallel, before the
# workers' data was aggregated, which reported 0% for a covered run.
function test_the_coverage_percentage_matches_the_console_report() {
  local output
  output=$(./bashunit --parallel --no-color --env "$TEST_ENV_FILE" --coverage \
    --report-md "$REPORT_DIR/summary.md" "$PASSING_FIXTURE" 2>/dev/null)

  local console_pct
  console_pct=$(echo "$output" | grep "^Total:" | sed 's/.*(\([0-9]*\)%).*/\1/')

  assert_not_empty "$console_pct"
  assert_contains "$console_pct% of tracked lines" "$(cat "$REPORT_DIR/summary.md")"
}

function test_the_slowest_tests_appear_only_with_profile() {
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" \
    --report-md "$REPORT_DIR/plain.md" "$PASSING_FIXTURE" >/dev/null 2>&1
  ./bashunit --no-parallel --no-color --env "$TEST_ENV_FILE" --profile \
    --report-md "$REPORT_DIR/profiled.md" "$PASSING_FIXTURE" >/dev/null 2>&1

  assert_not_contains "## Slowest tests" "$(cat "$REPORT_DIR/plain.md")"
  assert_contains "## Slowest tests" "$(cat "$REPORT_DIR/profiled.md")"
}
