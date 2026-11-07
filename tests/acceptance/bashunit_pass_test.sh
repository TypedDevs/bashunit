#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_when_a_test_passes_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output exit_code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file")" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_bashunit_when_a_test_passes_verbose_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output exit_code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --detailed)" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_different_verbose_snapshots_matches() {
  bashunit::todo \
    "The different snapshots for these tests should also be identical, option to choose snapshot name?"
}

function test_bashunit_when_a_test_passes_simple_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output exit_code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE_SIMPLE" "$test_file")" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_bashunit_when_a_test_passes_simple_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  local output exit_code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)" || exit_code=$?
  assert_match_snapshot "$output"
  assert_successful_code "" "" "$exit_code"
}

function test_different_simple_snapshots_matches() {
  bashunit::todo \
    "The different snapshots for these tests should also be identical, option to choose snapshot name?"
}
