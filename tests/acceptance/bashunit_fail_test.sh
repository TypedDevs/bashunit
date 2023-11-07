#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_when_a_test_fail_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_a_test_fail_verbose_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
}

function test_bashunit_when_a_test_fail_simple_output_env() {
  todo "Should print something like ...F."
  return

  # shellcheck disable=SC2317
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  # shellcheck disable=SC2317
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
  # shellcheck disable=SC2317
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
}

function test_bashunit_when_a_test_fail_simple_output_option() {
  todo "Should print something like ...F."
  return

  # shellcheck disable=SC2317
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  # shellcheck disable=SC2317
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
  # shellcheck disable=SC2317
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
}
