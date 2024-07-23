#!/bin/bash
set -euo pipefail

function set_up_before_script() {
  ORIGINAL_TERM=$TERM
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function set_up() {
  TERM=dumb
}

function tear_down() {
  TERM=$ORIGINAL_TERM
}

function test_bashunit_should_display_version() {
  local fixture
  fixture=$(printf "bashunit - %s" "$BASHUNIT_VERSION")

  todo "Add snapshots with regex to assert this test (part of the output changes every version)"
  assert_contains "$fixture" "$(./bashunit --env "$TEST_ENV_FILE" --version)"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" --version)"
}

function test_bashunit_should_display_help() {
  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" --help)"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" --help)"
}
