#!/usr/bin/env bash
set -euo pipefail

function test_missing_assertion_argument_is_a_usage_error() {
  local fixture=tests/acceptance/fixtures/assert_arity/missing.sh
  local output exit_code=0

  output=$(NO_COLOR=1 ./bashunit --no-parallel --skip-env-file "$fixture" 2>&1) || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "✗ Error: Wrong arg count" "$output"
  assert_contains "assert_same expects 2 arguments (expected, actual), got 1" "$output"
  assert_not_contains "but got" "$output"
}
