#!/usr/bin/env bash
set -euo pipefail

# The classifier scans a failing test's captured output for shell-error phrases.
# That output also carries bashunit's own rendering, so a failure message -- or
# a test that legitimately quotes a diagnostic -- used to be misread as a
# runtime error and reported twice, as Failed and as Error, for one cause.
function test_quoting_a_diagnostic_is_not_a_runtime_error() {
  local fixture=tests/acceptance/fixtures/runtime_error/quotes_a_diagnostic.sh
  local output exit_code=0

  output=$(NO_COLOR=1 ./bashunit --no-parallel --skip-env-file "$fixture" 2>&1) || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "✗ Failed: Quotes a shell diagnostic as data" "$output"
  assert_not_contains "✗ Error: Quotes a shell diagnostic as data" "$output"
}

# The regression guard: a test that really does hit a shell error must still be
# classified as one.
function test_a_real_shell_error_is_still_reported() {
  local fixture=tests/acceptance/fixtures/runtime_error/real_error.sh
  local output exit_code=0

  output=$(NO_COLOR=1 ./bashunit --no-parallel --skip-env-file "$fixture" 2>&1) || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "✗ Error: Hits a real shell error" "$output"
  assert_contains "command not found" "$output"
}
