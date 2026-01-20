#!/usr/bin/env bash

# Performance acceptance test for --no-fork mode
# Runs the standalone benchmark script and verifies it passes

function test_no_fork_performance_benchmark_passes() {
  local output
  output=$(./tests/benchmark/no_fork_performance_test.sh 2>&1)
  local exit_code=$?

  assert_equals 0 "$exit_code" "Benchmark should pass (no-fork faster than normal)"
  assert_contains "No-fork mode is" "$output"
  assert_contains "faster" "$output"
}
