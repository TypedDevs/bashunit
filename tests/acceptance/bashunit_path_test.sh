#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_WITH_PATH="tests/acceptance/fixtures/.env.with_path"
}

function test_bashunit_without_path_env_nor_argument() {
  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE")"
  assert_general_error "$(./bashunit --no-parallel --env "$TEST_ENV_FILE")"
}

function test_bashunit_with_argument_path() {
  local path="tests/acceptance/fixtures/tests_path"

  assert_match_snapshot "$(./bashunit --no-parallel "$path" --env "$TEST_ENV_FILE")"
  assert_successful_code "$(./bashunit --no-parallel "$path" --env "$TEST_ENV_FILE")"
}

function test_bashunit_with_env_default_path() {
  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_WITH_PATH")"
  assert_successful_code "$(./bashunit --no-parallel --env "$TEST_ENV_FILE_WITH_PATH")"
}

function test_bashunit_argument_overloads_default_path() {
  local path="tests/acceptance/fixtures/wrong_path"

  assert_match_snapshot "$(./bashunit --no-parallel "$path" --env "$TEST_ENV_FILE_WITH_PATH")"
  assert_general_error "$(./bashunit --no-parallel "$path" --env "$TEST_ENV_FILE_WITH_PATH")"
}
