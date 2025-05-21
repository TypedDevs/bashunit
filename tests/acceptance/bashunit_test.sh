#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_should_display_version() {
  local fixture
  fixture=$(printf "\e[1m\e[32mbashunit\e[0m - %s" "$BASHUNIT_VERSION")

  todo "Add snapshots with regex to assert this test (part of the output changes every version)"
  assert_contains "$fixture" "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --version)"
  assert_successful_code "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --version)"
}

function test_bashunit_should_display_help() {
  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --help)"
  assert_successful_code "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --help)"
}
