#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_no_color_flag_disables_colors() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --no-color --simple)

  # ANSI escape codes start with \x1b[ (ESC[) - should not be present
  assert_not_contains $'\e[' "$output"
}

function test_bashunit_no_color_env_var_disables_colors() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output
  output=$(NO_COLOR=1 ./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)

  # ANSI escape codes start with \x1b[ (ESC[) - should not be present
  assert_not_contains $'\e[' "$output"
}

function test_bashunit_colors_enabled_by_default() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh
  local output
  output=$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$test_file" --simple)

  # ANSI escape codes should be present by default
  assert_contains $'\e[' "$output"
}
