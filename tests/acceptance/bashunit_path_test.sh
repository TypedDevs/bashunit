#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_WITH_PATH="tests/acceptance/fixtures/.env.with_path"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_without_path_env_nor_argument() {
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE")"
}

function test_bashunit_with_argument_path() {
  local path="tests/acceptance/fixtures/tests_path"

  assert_match_snapshot "$(./bashunit "$path" --env "$TEST_ENV_FILE")"
  assert_successful_code "$(./bashunit "$path" --env "$TEST_ENV_FILE")"
}

function test_bashunit_with_env_default_path() {
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_WITH_PATH")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE_WITH_PATH")"
}

function test_bashunit_argument_overloads_default_path() {
  local path="tests/acceptance/fixtures/wrong_path"

  assert_match_snapshot "$(./bashunit "$path" --env "$TEST_ENV_FILE_WITH_PATH")"
  assert_general_error "$(./bashunit "$path" --env "$TEST_ENV_FILE_WITH_PATH")"
}
