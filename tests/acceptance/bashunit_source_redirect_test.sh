#!/usr/bin/env bash
set -euo pipefail

# `source "$file" 2>"$_BASHUNIT_RUN_OUTPUT_DIR/source_err"` fails when the run's
# scratch directory is missing -- and it fails on the *redirect*, so bash
# returns 1 having written nothing to the capture file. The runner read that as
# the test file failing to source and reported
#
#   Failed to source 'x_test.sh' (exit 1, 52 bytes, no stderr)
#
# against a file that was complete and valid. That message sent three separate
# investigations at the fixture (#1137). The directory going missing mid-run is
# a separate open question; a run should survive it either way.

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

# Two files: the first removes the run's scratch directory while it is being
# sourced, which is exactly the state the flake produces; the second must still
# be sourced and run.
function test_a_file_still_runs_when_the_run_scratch_dir_disappeared() {
  local dir
  dir="$(bashunit::temp_dir)"
  printf '%s\n' 'rm -rf "$_BASHUNIT_RUN_OUTPUT_DIR"
function test_removes_the_scratch_dir() { assert_same 1 1; }' >"$dir/a_killer_test.sh"
  printf '%s\n' 'function test_runs_after_the_scratch_dir_went_away() { assert_same 2 2; }' \
    >"$dir/b_victim_test.sh"

  local output code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" \
    "$dir/a_killer_test.sh" "$dir/b_victim_test.sh" 2>&1)" || code=$?
  output="$(printf '%s' "$output" | strip_ansi)"

  assert_same 0 "$code"
  assert_contains "2 passed" "$output"
  assert_not_contains "Failed to source" "$output"
}

# The genuine case must keep reporting: a file whose top level returns non-zero
# is still a source failure, and the message still says so.
function test_a_real_source_failure_is_still_reported() {
  local fixture
  fixture="$(bashunit::temp_file real_source_failure).sh"
  printf '%s\n' 'function test_never_runs() { assert_same 1 1; }
false' >"$fixture"

  local output code=0
  output="$(./bashunit --no-parallel --env "$TEST_ENV_FILE" "$fixture" 2>&1)" || code=$?
  output="$(printf '%s' "$output" | strip_ansi)"

  assert_same 1 "$code"
  assert_contains "Failed to source" "$output"
}
