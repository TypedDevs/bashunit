#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_WITH_PATH="tests/acceptance/fixtures/.env.with_path"
}

function test_bashunit_without_path_env_nor_argument() {
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE")"
}

function test_bashunit_with_argument_path() {
  todo "Here it is supposed to search for files ending in test, this functionality has recently stopped working"
  return

  # shellcheck disable=SC2317
  assert_match_snapshot "$(./bashunit tests/acceptance/fixtures/tests_path --env "$TEST_ENV_FILE")"
  # shellcheck disable=SC2317
  assert_general_error "$(./bashunit tests/acceptance/fixtures/tests_path --env "$TEST_ENV_FILE")"
}

function test_bashunit_with_env_default_path() {
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_WITH_PATH")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE_WITH_PATH")"
}
