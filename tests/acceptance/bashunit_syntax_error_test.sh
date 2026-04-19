#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'
}

function test_bashunit_when_test_file_has_syntax_error() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_syntax_error.sh

  local actual_raw
  set +e
  actual_raw="$(LC_ALL=C LANG=C ./bashunit \
    --no-parallel --detailed --env "$TEST_ENV_FILE" "$test_file" 2>&1)"
  set -e

  local actual
  actual="$(printf "%s" "$actual_raw" | strip_ansi)"

  assert_contains "failed" "$actual"
  assert_contains "Error" "$actual"
  assert_general_error "$(LC_ALL=C LANG=C ./bashunit \
    --no-parallel --env "$TEST_ENV_FILE" "$test_file" 2>&1)"
}
