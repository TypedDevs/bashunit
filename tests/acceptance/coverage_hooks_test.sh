#!/usr/bin/env bash
# shellcheck disable=SC2034

LCOV_FILE=""

function set_up_before_script() {
  LCOV_FILE="$(bashunit::temp_file "lcov-hooks")"
}

function test_coverage_tracks_src_lines_executed_in_hooks() {
  local output
  output=$(./bashunit \
    --coverage \
    --no-coverage-report \
    --coverage-paths "src/" \
    --coverage-report "$LCOV_FILE" \
    tests/acceptance/fixtures/test_coverage_hooks.sh 2>&1)

  assert_successful_code

  local lcov
  lcov="$(cat "$LCOV_FILE" 2>/dev/null)"

  assert_not_empty "$lcov"
  assert_contains "SF:" "$lcov"
  assert_contains "DA:" "$lcov"
}
