#!/usr/bin/env bash
set -euo pipefail

function test_non_numeric_spy_count_is_a_usage_error() {
  local fixture=tests/acceptance/fixtures/spy_usage/non_numeric.sh
  local output exit_code=0

  output=$(NO_COLOR=1 ./bashunit --no-parallel --skip-env-file "$fixture" 2>&1) || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "✗ Error: Swapped count and spy" "$output"
  assert_contains \
    "assert_have_been_called_times expects a numeric count first (expected_count, command), got 'my_cmd'" \
    "$output"
  # The raw shell diagnostic must not reach the user.
  assert_not_contains "integer expression expected" "$output"
}
