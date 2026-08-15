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
#
# Pinned to LC_ALL=C on purpose. bash translates its diagnostics, and the phrase
# list this classifier matches on is English only, so under a Spanish or
# Japanese locale a genuine "command not found" is not recognised at all. That
# is a pre-existing limitation, not something this test should assert about;
# forcing the C locale keeps it testing the classification mechanics.
function test_a_real_shell_error_is_still_reported() {
  local fixture=tests/acceptance/fixtures/runtime_error/real_error.sh
  local output exit_code=0

  output=$(LC_ALL=C NO_COLOR=1 ./bashunit --no-parallel --skip-env-file "$fixture" 2>&1) || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "✗ Error: Hits a real shell error" "$output"
  assert_contains "command not found" "$output"
}

# A test can fail an assertion *and* hit a shell error. The reported error must
# be the diagnostic alone: extracting it from the whole capture stripped to the
# first ": " anywhere, which landed inside bashunit's own "✗ Failed: <name>"
# rendering, so the error read as the failure text with the diagnostic glued on
# ("...but got 'b' at file:2file: line 8: nope: command not found").
function test_an_assertion_failure_does_not_leak_into_the_error_message() {
  local fixture=tests/acceptance/fixtures/runtime_error/fails_and_errors.sh
  local output exit_code=0

  output=$(LC_ALL=C NO_COLOR=1 ./bashunit --no-parallel --skip-env-file "$fixture" 2>&1) || exit_code=$?

  assert_same 1 "$exit_code"
  assert_contains "line 8: no_such_command_from_a_fixture: command not found" "$output"
  # The failure text must not appear inside the error message line.
  assert_not_contains "but got  'b'    at" "$output"
}
