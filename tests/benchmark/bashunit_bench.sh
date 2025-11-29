#!/usr/bin/env bash
set -euo pipefail

# @revs=3 @its=2
function bench_bashunit_runs_benchmarks() {
  local bench_file=./tests/benchmark/fixtures/bashunit_sleep_bench.sh

  local output
  output="$(./bashunit bench "$bench_file")"
  assert_matches "Benchmark Results" "$output"
  assert_successful_code "$output"
}

# @revs=1 @its=1
function bench_bashunit_functional_run() {
  local bench_file=./tests/benchmark/fixtures/bashunit_sleep_bench.sh

  local output
  output="$(./bashunit bench "$bench_file")"
  assert_matches "Benchmark Results" "$output"
  assert_successful_code "$output"
}

# @revs=1 @its=1 @max_ms=600
function bench_bashunit_default_path() {
  local env_file=./tests/benchmark/fixtures/.env.with_path

  local output
  output="$(./bashunit bench --env "$env_file")"
  assert_matches "Benchmark Results" "$output"
  assert_successful_code "$output"
}
