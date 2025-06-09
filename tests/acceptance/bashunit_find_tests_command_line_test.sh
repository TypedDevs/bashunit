#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_all_tests_files_within_a_directory() {
  local path="./tests/acceptance/fixtures"

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$path")"
}

function test_all_tests_files_within_a_file() {
  local path="./tests/acceptance/fixtures/tests_path/a_test.sh"

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$path")"
}

function test_all_tests_files_with_wildcard() {
  local path='./tests/acceptance/fixtures/tests_path/*'

  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$path")"
}

function test_error_when_no_tests_found() {
  local path="./non_existing_path"

  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$path")"
}
