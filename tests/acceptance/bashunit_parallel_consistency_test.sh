#!/usr/bin/env bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_parallel_and_sequential_results_match() {
  local file1=tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local file2=tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh
  local file3=tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh

  local sequential_output
  sequential_output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$file1" "$file2" "$file3")

  local parallel_output
  parallel_output=$(./bashunit --parallel --env "$TEST_ENV_FILE" "$file1" "$file2" "$file3")

  local sequential_summary
  sequential_summary=$(echo "$sequential_output" | grep -e "Tests:" -e "Assertions:" | tr '\n' ' ')

  local parallel_summary
  parallel_summary=$(echo "$parallel_output" | grep -e "Tests:" -e "Assertions:" | tr '\n' ' ')

  assert_equals "$sequential_summary" "$parallel_summary"
}
