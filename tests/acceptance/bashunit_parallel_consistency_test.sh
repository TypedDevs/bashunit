#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

# The counts of the run's own summary, and nothing else.
#
# These tests used to scrape `[0-9]+ (passed|total)` over the whole capture,
# which made them a hostage to any other line carrying a number: #1048 saw
# Ubuntu and Alpine fail in the same run with an extra `0 total 0 total` pair
# in front of the real summary -- a zero-test summary that came from somewhere
# other than the run being measured. Anchoring to the LAST `Tests:` and
# `Assertions:` lines measures the summary of the run that just finished,
# whatever else ended up in the stream.
#
# Arguments: $1 - captured output
function summary_counts() {
  local output=$1
  local tests_line assertions_line

  tests_line=$(printf '%s\n' "$output" | "$GREP" -E 'Tests:' | tail -1)
  assertions_line=$(printf '%s\n' "$output" | "$GREP" -E 'Assertions:' | tail -1)

  printf '%s%s' \
    "$(printf '%s\n' "$tests_line" | "$GREP" -oE '[0-9]+ (passed|total)' | tr '\n' ' ')" \
    "$(printf '%s\n' "$assertions_line" | "$GREP" -oE '[0-9]+ (passed|total)' | tr '\n' ' ')"
}

function test_parallel_and_sequential_results_match() {
  local file1=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local file2=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
  local file3=tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh

  local sequential_output
  sequential_output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "$file1" "$file2" "$file3" 2>&1) || true

  local parallel_output
  parallel_output=$(NO_COLOR=1 ./bashunit --parallel --env "$TEST_ENV_FILE" \
    "$file1" "$file2" "$file3" 2>&1) || true

  assert_equals "$(summary_counts "$sequential_output")" \
    "$(summary_counts "$parallel_output")"
}

function test_jobs_auto_caps_at_detected_cores_and_matches_sequential() {
  local file1=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local file2=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  local sequential_output
  sequential_output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$file1" "$file2" 2>&1) || true

  local auto_output
  auto_output=$(NO_COLOR=1 ./bashunit --jobs auto --env "$TEST_ENV_FILE" "$file1" "$file2" 2>&1) || true

  assert_equals "$(summary_counts "$sequential_output")" \
    "$(summary_counts "$auto_output")"
}

# Per-test results used to be bucketed by the test file's BASENAME, so two files
# sharing one in different directories wrote into the same bucket and their
# per-suite ordinals collided -- the second file's results overwrote the first's,
# silently, with the run still green (#959). Mirroring a source tree in tests/
# makes duplicate basenames normal, so this is a realistic layout, not a corner.
function test_parallel_does_not_lose_same_named_files_in_different_dirs() {
  local one=tests/acceptance/fixtures/dup_basename/one/test_dup.sh
  local two=tests/acceptance/fixtures/dup_basename/two/test_dup.sh

  local sequential_output
  sequential_output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$one" "$two" 2>&1) || true

  local parallel_output
  parallel_output=$(NO_COLOR=1 ./bashunit --parallel --env "$TEST_ENV_FILE" "$one" "$two" 2>&1) || true

  # Counts only, not the rendered line: the parallel spinner leaves control bytes
  # and indentation on the summary, which is cosmetic and not what this asserts.
  local sequential_counts parallel_counts
  sequential_counts=$(summary_counts "$sequential_output")
  parallel_counts=$(summary_counts "$parallel_output")

  assert_same "$sequential_counts" "$parallel_counts"
  # Guard against both sides collapsing to nothing and matching vacuously.
  assert_contains "2 total" "$sequential_counts"
}

function test_parallel_counts_tests_under_a_hidden_relative_dir() {
  local dir runner="$PWD/bashunit" env_file="$PWD/$TEST_ENV_FILE"
  dir="$(bashunit::temp_dir hidden_parallel)"
  local passing=".hidden-tests/hidden_pass_test.sh"
  local failing=".hidden-tests/hidden_fail_test.sh"
  mkdir -p "$dir/.hidden-tests"
  printf 'function test_hidden_pass() { assert_same 1 1; }\n' >"$dir/$passing"
  printf 'function test_hidden_fail() { assert_same 1 2; }\n' >"$dir/$failing"

  local sequential_output
  sequential_output=$(cd "$dir" && NO_COLOR=1 "$runner" --no-parallel --env "$env_file" \
    "$passing" "$failing" 2>&1) || true
  local parallel_output
  parallel_output=$(cd "$dir" && NO_COLOR=1 "$runner" --parallel --env "$env_file" "$passing" "$failing" 2>&1) || true

  local sequential_counts parallel_counts
  sequential_counts=$(summary_counts "$sequential_output")
  parallel_counts=$(summary_counts "$parallel_output")

  assert_same "$sequential_counts" "$parallel_counts"
  # Guard against both sides collapsing to nothing and matching vacuously.
  assert_contains "2 total" "$sequential_counts"
}

function test_parallel_keeps_hidden_and_visible_paths_distinct() {
  local dir runner="$PWD/bashunit" env_file="$PWD/$TEST_ENV_FILE"
  dir="$(bashunit::temp_dir hidden_visible_parallel)"
  mkdir -p "$dir/tests" "$dir/.tests"
  printf 'function test_visible_path_fails() { assert_same 1 2; }\n' >"$dir/tests/example_test.sh"
  printf 'function test_hidden_path_passes() { assert_same 1 1; }\n' >"$dir/.tests/example_test.sh"

  local sequential_output parallel_output sequential_status=0 parallel_status=0
  sequential_output=$(cd "$dir" && NO_COLOR=1 "$runner" --no-parallel --env "$env_file" \
    tests/example_test.sh .tests/example_test.sh 2>&1) || sequential_status=$?
  # One job makes the hidden file overwrite the visible file deterministically if their keys collide.
  parallel_output=$(cd "$dir" && NO_COLOR=1 "$runner" --parallel --jobs 1 --env "$env_file" \
    tests/example_test.sh .tests/example_test.sh 2>&1) || parallel_status=$?

  assert_same "1" "$sequential_status"
  assert_same "$sequential_status" "$parallel_status"
  assert_same "$(summary_counts "$sequential_output")" "$(summary_counts "$parallel_output")"
  assert_contains "2 total" "$(summary_counts "$parallel_output")"
}

function test_parallel_preserves_result_keys_at_the_filename_limit() {
  local dir runner="$PWD/bashunit" env_file="$PWD/$TEST_ENV_FILE" filename
  dir="$(bashunit::temp_dir parallel_long_path)"
  filename="$(printf '%0247d_test.sh' 0)"
  mkdir -p "$dir/ab"
  printf 'function test_long_path_passes() { assert_same 1 1; }\n' >"$dir/ab/$filename"

  local output status=0
  output=$(cd "$dir" && NO_COLOR=1 "$runner" --parallel --jobs 1 --env "$env_file" \
    "ab/$filename" 2>&1) || status=$?

  assert_same "0" "$status"
  assert_contains "1 passed 1 total" "$(summary_counts "$output")"
}

# The shape #1048 reported: a zero-test summary in front of the real one. The
# source of that stray summary was never reproduced -- 40+ local attempts,
# including under concurrent load, never produced one -- so this pins the
# scrape against it rather than the cause.
function test_summary_counts_ignores_a_stray_summary_before_the_real_one() {
  local capture="Tests:      0 total
Assertions: 0 total
Tests:      2 passed, 2 total
Assertions: 2 passed, 2 total"

  assert_same "2 passed 2 total 2 passed 2 total " "$(summary_counts "$capture")"
}

function test_summary_counts_reads_a_plain_run() {
  local capture="Running tests/example_test.sh
Tests:      3 passed, 3 total
Assertions: 5 passed, 5 total"

  assert_same "3 passed 3 total 5 passed 5 total " "$(summary_counts "$capture")"
}

# A file-scoped teardown has to run after the file's tests, not alongside them.
# Under --parallel the runner dispatched the worker and ran the hook on the very
# next line, so a resource acquired in set_up_before_script vanished mid-test and
# the file failed in parallel while passing sequentially (#1320).
function test_parallel_runs_tear_down_after_script_after_the_files_tests() {
  local dir fixture
  dir="$(bashunit::temp_dir parallel_file_teardown)"
  fixture="$dir/shared_fixture_test.sh"
  {
    printf 'function set_up_before_script() {\n'
    printf '  : >"$SHARED_FIXTURE"\n'
    printf '}\n'
    printf 'function tear_down_after_script() {\n'
    printf '  rm -f "$SHARED_FIXTURE"\n'
    printf '}\n'
    printf 'function test_reads_the_shared_fixture() {\n'
    printf '  sleep 0.5\n'
    printf '  assert_file_exists "$SHARED_FIXTURE"\n'
    printf '}\n'
  } >"$fixture"

  local sequential_output parallel_output
  sequential_output=$(SHARED_FIXTURE="$dir/sequential.fixture" NO_COLOR=1 \
    ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1) || true
  parallel_output=$(SHARED_FIXTURE="$dir/parallel.fixture" NO_COLOR=1 \
    ./bashunit --parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1) || true

  local sequential_counts parallel_counts
  sequential_counts=$(summary_counts "$sequential_output")
  parallel_counts=$(summary_counts "$parallel_output")

  assert_same "$sequential_counts" "$parallel_counts"
  # Guard against both sides failing the same way and matching vacuously.
  assert_contains "1 passed 1 total" "$sequential_counts"
}
