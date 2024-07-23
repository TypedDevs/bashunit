#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_when_a_test_passes_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_a_test_passes_verbose_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
}

function test_different_verbose_snapshots_matches() {
  todo "The different snapshots for these tests should also be identical to each other, option to choose snapshot name?"
}

function test_bashunit_when_a_test_passes_simple_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
}

function test_bashunit_when_a_test_passes_simple_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
}

function test_different_simple_snapshots_matches() {
  todo "The different snapshots for these tests should also be identical to each other, option to choose snapshot name?"
}
