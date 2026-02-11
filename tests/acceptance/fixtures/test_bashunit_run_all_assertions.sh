#!/usr/bin/env bash

function test_multiple_failures_with_run_all() {
  assert_same 1 2 # First failure
  assert_same 3 4 # Second failure - only runs with --run-all
  assert_same 5 6 # Third failure - only runs with --run-all
}

function test_pass_after_failure() {
  assert_same 1 2 # Failure
  assert_same 7 7 # Pass - only runs with --run-all
}

function test_all_pass() {
  assert_same 1 1
  assert_same 2 2
}
