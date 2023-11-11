#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_all_tests_files_within_a_directory() {
  local path="./tests/acceptance/fixtures"

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$path")"
}

function test_all_tests_files_within_a_file() {
  local path="./tests/acceptance/fixtures/tests_path/a_test.sh"

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$path")"
}

function test_all_tests_files_with_wildcard() {
  todo "it is not working yet, but I don't know why..."
  return

  local path="./tests/acceptance/fixtures/tests_path/*_test.sh"

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$path")"
}
