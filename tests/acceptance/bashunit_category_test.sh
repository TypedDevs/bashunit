#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_run_with_category_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_categories.sh
  assert_match_snapshot "$(./bashunit --no-parallel --env "$TEST_ENV_FILE" --category slow "$test_file")"
}
