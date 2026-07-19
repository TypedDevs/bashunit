#!/usr/bin/env bash
set -euo pipefail

# Regression test for https://github.com/TypedDevs/bashunit/issues/829
# Test functions must be unset once their file has been processed: they stay
# defined in the main shell otherwise, and every test's $() subshell forks an
# ever-fatter process, making multi-file runs quadratic in file count.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_test_functions_are_unset_after_their_file_ran() {
  local first_file=./tests/acceptance/fixtures/test_fn_cleanup_first.sh
  local second_file=./tests/acceptance/fixtures/test_fn_cleanup_second.sh

  local actual
  actual="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$first_file" "$second_file" | strip_ansi)"

  assert_contains "2 passed, 2 total" "$actual"
}

function test_test_functions_are_unset_after_their_file_ran_in_parallel() {
  local first_file=./tests/acceptance/fixtures/test_fn_cleanup_first.sh
  local second_file=./tests/acceptance/fixtures/test_fn_cleanup_second.sh

  local actual
  actual="$(./bashunit --parallel --env "$TEST_ENV_FILE" "$first_file" "$second_file" | strip_ansi)"

  assert_contains "2 passed, 2 total" "$actual"
}
