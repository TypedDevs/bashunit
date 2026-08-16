#!/usr/bin/env bash
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

# 2>&1 because the answer is now on stderr, where a wrong invocation belongs
# (the same stream abort_unknown_option uses). Without it this snapshot records
# an empty string and pins nothing.
function test_bashunit_argument_overloads_default_path() {
  local path="tests/acceptance/fixtures/wrong_path"

  assert_match_snapshot "$(./bashunit --no-parallel "$path" --env "$TEST_ENV_FILE_WITH_PATH" 2>&1)"
  assert_general_error "$(./bashunit --no-parallel "$path" --env "$TEST_ENV_FILE_WITH_PATH" 2>&1)"
}

# The override has to hold when the argument selects NOTHING, which is where it
# used to give way: zero files read as "no path was given", so the default path
# ran instead and the run passed. Asking for one directory and being handed
# another one's results is the worst shape of all -- green, and about tests the
# caller never named (#1263).
function test_an_argument_selecting_nothing_does_not_fall_back_to_the_default_path() {
  local empty_dir
  empty_dir="$(bashunit::temp_dir)"

  local ec=0
  local output
  output=$(./bashunit --no-parallel "$empty_dir" --env "$TEST_ENV_FILE_WITH_PATH" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "No tests found" "$output"
  assert_not_contains "Assert greater and less than" "$output"
}
