#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_all_tests_files_within_a_directory() {
  local test_dir=./tests/acceptance/fixtures

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_dir")"
}

function test_all_tests_files_within_a_file() {
  local test_dir=./tests/acceptance/fixtures/tests_path/a_test.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_dir")"
}
