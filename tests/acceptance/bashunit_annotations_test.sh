#!/usr/bin/env bash

# --test-timeout and --retry are run-wide, but the need is per test: one
# integration test needs 30s while the other 400 stay strict.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  FIXTURE="tests/acceptance/fixtures/test_bashunit_annotations.sh"
  BAD_TIMEOUT="tests/acceptance/fixtures/test_bashunit_annotations_bad_timeout.sh"
  BAD_RETRY="tests/acceptance/fixtures/test_bashunit_annotations_bad_retry.sh"
}

function set_up() {
  COUNTER_FILE="$(bashunit::temp_file)"
  export BASHUNIT_ANNOTATIONS_COUNTER="$COUNTER_FILE"
  printf '0' >"$COUNTER_FILE"
}

function tear_down() {
  unset BASHUNIT_ANNOTATIONS_COUNTER
}

function run_fixture() { # $1 = extra flags, $2 = filter
  # shellcheck disable=SC2086
  NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" $1 \
    --filter "$2" "$FIXTURE" 2>&1 || true
}

function test_skip_annotation_reports_the_test_skipped_with_its_reason() {
  local output
  output=$(run_fixture "" "test_annotated_skip_never_runs")

  assert_contains "Skipped: Annotated skip never runs" "$output"
  assert_contains "needs a live database" "$output"
  assert_not_contains "unreachable" "$output"
}

function test_skip_annotation_works_without_a_reason_and_on_both_definition_styles() {
  local output
  output=$(run_fixture "" "test_annotated_skip_without_reason")

  assert_contains "Skipped: Annotated skip without reason" "$output"
  assert_contains "1 skipped" "$output"
}

function test_timeout_annotation_kills_a_slow_test_without_a_global_timeout() {
  local output
  output=$(run_fixture "" "test_annotated_timeout_kills_a_slow_test")

  assert_contains "Test timed out after 1s" "$output"
}

function test_timeout_zero_disables_the_global_timeout_for_that_test() {
  local output
  output=$(run_fixture "--test-timeout 1" "test_annotated_timeout_zero")

  assert_contains "1 passed" "$output"
  assert_not_contains "timed out" "$output"
}

function test_retry_annotation_retries_only_that_test() {
  local output
  output=$(run_fixture "" "test_annotated_retry")

  assert_contains "1 passed" "$output"
  assert_same "3" "$(cat "$COUNTER_FILE")"
}

function test_a_blank_line_breaks_the_annotation_block() {
  local output
  output=$(run_fixture "" "test_a_blank_line_breaks")

  assert_contains "1 passed" "$output"
  assert_not_contains "Skipped" "$output"
}

function test_annotations_work_under_parallel() {
  local output
  output=$(NO_COLOR=1 ./bashunit --parallel --env "$TEST_ENV_FILE" \
    --filter "test_annotated_skip_never_runs" "$FIXTURE" 2>&1 || true)

  assert_contains "1 skipped" "$output"
  assert_not_contains "unreachable" "$output"
}

function test_a_malformed_timeout_fails_the_run() {
  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$BAD_TIMEOUT" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "@timeout" "$output"
  assert_contains "abc" "$output"
}

function test_a_malformed_retry_fails_the_run() {
  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$BAD_RETRY" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "@retry" "$output"
}

# The annotation scan rides on the provider-map pass, so it must not add an awk
# fork per file (#773 budget, guarded by bashunit_run_forks_test.sh).
function test_annotations_combine_with_tags() {
  local output
  output=$(run_fixture "--tag slow" "test_annotated_timeout_kills_a_slow_test")

  assert_contains "Test timed out after 1s" "$output"
}

function run_bad_annotation_fixture() { # $1 = annotation line, $2 = parallel flag
  local dir fixture
  dir="$(bashunit::temp_dir annotation_cleanup)"
  fixture="$dir/bad_annotation_test.sh"
  BAD_ANNOTATION_MARKER="$dir/resource"
  {
    printf 'RESOURCE=""\n'
    printf 'function set_up_before_script() {\n'
    printf '  RESOURCE="$CLEANUP_MARKER"\n'
    printf '  : >"$RESOURCE"\n'
    printf '}\n'
    printf 'function tear_down_after_script() {\n'
    printf '  rm -f "$RESOURCE"\n'
    printf '}\n'
    printf '%s\n' "$1"
    printf 'function test_bad_annotation() { assert_same "ok" "ok"; }\n'
  } >"$fixture"

  BAD_ANNOTATION_EC=0
  BAD_ANNOTATION_OUTPUT=$(CLEANUP_MARKER="$BAD_ANNOTATION_MARKER" NO_COLOR=1 \
    ./bashunit "$2" --env "$TEST_ENV_FILE" "$fixture" 2>&1) || BAD_ANNOTATION_EC=$?
}

# A malformed annotation aborts from inside call_test_functions, which used to
# take the file's tear_down_after_script down with it (#1329).
function test_a_malformed_timeout_runs_the_file_teardown() {
  run_bad_annotation_fixture '# @timeout abc' --no-parallel

  assert_general_error "" "" "$BAD_ANNOTATION_EC"
  assert_contains "@timeout 'abc'" "$BAD_ANNOTATION_OUTPUT"
  assert_file_not_exists "$BAD_ANNOTATION_MARKER"
}

function test_a_malformed_timeout_runs_the_file_teardown_under_parallel() {
  run_bad_annotation_fixture '# @timeout abc' --parallel

  assert_general_error "" "" "$BAD_ANNOTATION_EC"
  assert_contains "@timeout 'abc'" "$BAD_ANNOTATION_OUTPUT"
  assert_file_not_exists "$BAD_ANNOTATION_MARKER"
}

function test_a_malformed_retry_runs_the_file_teardown() {
  run_bad_annotation_fixture '# @retry abc' --no-parallel

  assert_general_error "" "" "$BAD_ANNOTATION_EC"
  assert_contains "@retry 'abc'" "$BAD_ANNOTATION_OUTPUT"
  assert_file_not_exists "$BAD_ANNOTATION_MARKER"
}

function test_a_malformed_retry_runs_the_file_teardown_under_parallel() {
  run_bad_annotation_fixture '# @retry abc' --parallel

  assert_general_error "" "" "$BAD_ANNOTATION_EC"
  assert_contains "@retry 'abc'" "$BAD_ANNOTATION_OUTPUT"
  assert_file_not_exists "$BAD_ANNOTATION_MARKER"
}

function run_bad_annotation_alongside_a_passing_file() { # $1 = annotation line
  local dir
  dir="$(bashunit::temp_dir annotation_abort)"
  BAD_ANNOTATION_MARKER="$dir/resource"
  {
    printf 'function set_up_before_script() { : >"$CLEANUP_MARKER"; }\n'
    printf 'function tear_down_after_script() { rm -f "$CLEANUP_MARKER"; }\n'
    printf '%s\n' "$1"
    printf 'function test_bad_annotation_beside_a_good_file() { assert_same "ok" "ok"; }\n'
  } >"$dir/bad_annotation_test.sh"
  printf 'function test_good_beside_a_bad_annotation() { assert_same "ok" "ok"; }\n' \
    >"$dir/good_test.sh"

  BAD_ANNOTATION_EC=0
  BAD_ANNOTATION_OUTPUT=$(CLEANUP_MARKER="$BAD_ANNOTATION_MARKER" NO_COLOR=1 \
    ./bashunit --parallel --env "$TEST_ENV_FILE" "$dir" 2>&1) || BAD_ANNOTATION_EC=$?
}

# Sequentially the abort exits the run. Under --parallel the parent is several
# files ahead, so the worker's abort has to travel to it: without that the run
# reported "All tests passed" and exited 0 over a file that never ran (#1335).
function test_a_malformed_timeout_fails_a_parallel_run_beside_a_passing_file() {
  run_bad_annotation_alongside_a_passing_file '# @timeout abc'

  assert_general_error "" "" "$BAD_ANNOTATION_EC"
  assert_contains "@timeout 'abc'" "$BAD_ANNOTATION_OUTPUT"
  assert_not_contains "All tests passed" "$BAD_ANNOTATION_OUTPUT"
  assert_file_not_exists "$BAD_ANNOTATION_MARKER"
}

function test_a_malformed_retry_fails_a_parallel_run_beside_a_passing_file() {
  run_bad_annotation_alongside_a_passing_file '# @retry abc'

  assert_general_error "" "" "$BAD_ANNOTATION_EC"
  assert_contains "@retry 'abc'" "$BAD_ANNOTATION_OUTPUT"
  assert_not_contains "All tests passed" "$BAD_ANNOTATION_OUTPUT"
}

# #1301 fixed a file-level failure being counted twice: two failed tests in the
# reports against one in the console summary. The abort travels the same channel,
# so it has to stay counted once.
function test_a_malformed_annotation_is_counted_once_under_parallel() {
  run_bad_annotation_alongside_a_passing_file '# @timeout abc'

  assert_contains "1 passed" "$BAD_ANNOTATION_OUTPUT"
  assert_contains "1 failed" "$BAD_ANNOTATION_OUTPUT"
  assert_contains "2 total" "$BAD_ANNOTATION_OUTPUT"
}
