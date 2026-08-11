#!/usr/bin/env bash
set -euo pipefail

# A failing assertion is not an execution error. bashunit::assert_that returns 1
# on failure, so a custom assertion that ends with it makes the whole test body
# exit 1, and the runner used to report a second, spurious `✗ Error` on top of
# the `✗ Failed` the assertion had already printed. Writing `return 0` at the end
# of every custom assertion worked around it; the runner should not need that.

function set_up_before_script() {
  FIXTURES="./tests/acceptance/fixtures/custom_assert_trailing"
}

function _run_trailing_fixture() {
  ./bashunit --no-parallel --no-color \
    --boot "$FIXTURES/bootstrap.sh" "$FIXTURES/trailing.sh" 2>&1 || true
}

function test_a_trailing_custom_assertion_reports_one_failure() {
  local output
  output="$(_run_trailing_fixture)"

  assert_contains "✗ Failed: Value is not positive" "$output"
  assert_contains "Tests:      1 failed, 1 total" "$output"
}

function test_a_trailing_custom_assertion_reports_no_execution_error() {
  local output
  output="$(_run_trailing_fixture)"

  assert_not_contains "✗ Error" "$output"
}

# A real runtime error must still be reported as an error, so the fix cannot be
# "ignore a non-zero exit code whenever any assertion failed".
function test_a_runtime_error_after_a_failed_assertion_is_still_an_error() {
  local dir output
  dir="$(bashunit::temp_dir)"
  printf 'function test_broken() {\n  assert_same "a" "b"\n  no_such_command_at_all\n}\n' \
    >"$dir/broken.sh"

  output="$(./bashunit --no-parallel --no-color "$dir/broken.sh" 2>&1 || true)"

  assert_contains "✗ Error" "$output"
  assert_contains "command not found" "$output"
}
