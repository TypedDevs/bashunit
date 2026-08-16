#!/usr/bin/env bash
set -euo pipefail

# The total runtime is the one number a run reports about itself, and it failed
# in the only way a number can fail badly: silently. A pipe inside
# math::calculate could not be staged, the calculation produced nothing, and the
# footer said "Time taken: 0ms" for a multi-second suite while every test passed
# and the run exited 0 (#1271).
#
# It took a directory of test files to show, so this pays for a nested run over
# many of them. Under 60 the fd state that triggers it does not build up.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FILE_COUNT=80
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir many_files)"
  local i=1
  while [ "$i" -le "$FILE_COUNT" ]; do
    printf 'function test_n%s() { assert_same 1 1; }\n' "$i" >"$WORKDIR/n${i}_test.sh"
    i=$((i + 1))
  done
}

# One nested run for all four assertions: the run is the expensive part, and
# splitting them would buy nothing but a second 80-file suite.
function test_a_run_over_many_files_reports_a_real_total_runtime() {
  local output
  output=$("$BASHUNIT_BIN" --no-parallel --skip-env-file "$WORKDIR" 2>&1) || true

  assert_contains "$FILE_COUNT passed" "$output"
  assert_not_contains "Time taken: 0ms" "$output"
  # What the shell printed while the run still reported success. They reach
  # stderr, so a caller merging streams gets them in the middle of its output,
  # and they are the only trace the failure leaves.
  assert_not_contains "Bad file descriptor" "$output"
  assert_not_contains "Broken pipe" "$output"
}
