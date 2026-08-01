#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_parallel_and_sequential_results_match() {
  local file1=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local file2=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
  local file3=tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh

  local sequential_output
  sequential_output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$file1" "$file2" "$file3" 2>&1) || true

  local parallel_output
  parallel_output=$(./bashunit --parallel --env "$TEST_ENV_FILE" "$file1" "$file2" "$file3" 2>&1) || true

  local sequential_summary
  sequential_summary=$(echo "$sequential_output" | grep -e "Tests:" -e "Assertions:" | tr '\n' ' ') || true

  local parallel_summary
  parallel_summary=$(echo "$parallel_output" | grep -e "Tests:" -e "Assertions:" | tr '\n' ' ') || true

  assert_equals "$sequential_summary" "$parallel_summary"
}

function test_jobs_auto_caps_at_detected_cores_and_matches_sequential() {
  local file1=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local file2=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  local sequential_output
  sequential_output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$file1" "$file2" 2>&1) || true

  local auto_output
  auto_output=$(./bashunit --jobs auto --env "$TEST_ENV_FILE" "$file1" "$file2" 2>&1) || true

  local sequential_summary
  sequential_summary=$(echo "$sequential_output" | grep -e "Tests:" -e "Assertions:" | tr '\n' ' ') || true

  local auto_summary
  auto_summary=$(echo "$auto_output" | grep -e "Tests:" -e "Assertions:" | tr '\n' ' ') || true

  assert_equals "$sequential_summary" "$auto_summary"
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
  sequential_output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$one" "$two" 2>&1) || true

  local parallel_output
  parallel_output=$(./bashunit --parallel --env "$TEST_ENV_FILE" "$one" "$two" 2>&1) || true

  # Counts only, not the rendered line: the parallel spinner leaves control bytes
  # and indentation on the summary, which is cosmetic and not what this asserts.
  local sequential_counts
  sequential_counts=$(echo "$sequential_output" | grep -oE '[0-9]+ (passed|total)' | tr '\n' ' ') || true

  local parallel_counts
  parallel_counts=$(echo "$parallel_output" | grep -oE '[0-9]+ (passed|total)' | tr '\n' ' ') || true

  assert_same "$sequential_counts" "$parallel_counts"
  # Guard against both sides collapsing to nothing and matching vacuously.
  assert_contains "2 total" "$sequential_counts"
}
