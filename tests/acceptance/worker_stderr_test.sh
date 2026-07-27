#!/usr/bin/env bash

# Parallel workers used to run with `2>/dev/null`, so anything written to
# stderr inside the worker but outside a test body vanished, and the same run
# reported differently depending on --parallel (#864).
#
# The fixture's provider is also executed by the test-counting pass in the main
# shell, so merely *finding* the diagnostic proves nothing — it leaks in from
# that pass either way. What the bug actually broke is the two modes agreeing,
# so that is what these compare.

FIXTURE="tests/acceptance/fixtures/test_worker_stderr.sh"

function _count_diagnostic_in() {
  local parallel_flag="$1"

  ./bashunit "$parallel_flag" "$FIXTURE" 2>&1 |
    grep -c "WORKER-SCOPE-DIAGNOSTIC"
}

function test_parallel_reports_worker_stderr_as_often_as_sequential() {
  local sequential parallel
  sequential="$(_count_diagnostic_in --no-parallel)"
  parallel="$(_count_diagnostic_in --parallel)"

  assert_not_equals "0" "$sequential"
  assert_equals "$sequential" "$parallel"
}

function test_parallel_run_attributes_worker_stderr_to_its_file() {
  local output
  output=$(./bashunit --parallel "$FIXTURE" 2>&1)

  # On a platform bashunit does not support parallel on (anything outside
  # macOS/Ubuntu/Alpine/Windows, e.g. NixOS) `--parallel` degrades to
  # sequential. There is no worker then, so stderr reaches the terminal
  # directly and there is no block to attribute.
  case "$output" in
  *"Fallback using --no-parallel"*)
    bashunit::skip "--parallel is not supported on this platform"
    return 0
    ;;
  esac

  assert_contains "Stderr from $FIXTURE" "$output"
}

function test_parallel_run_stays_quiet_when_no_worker_writes_stderr() {
  local output
  output=$(./bashunit --parallel tests/acceptance/fixtures/test_coverage_engine.sh 2>&1)

  assert_not_contains "Stderr from" "$output"
}
