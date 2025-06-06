#!/usr/bin/env bash
set -euo pipefail

function bench_bashunit_runs_benchmarks() {
  local bench_file=./tests/benchmark/fixtures/bashunit_sleep.sh

  local output
  output="$(./bashunit --bench "$bench_file")"
  assert_matches "Benchmark Results" "$output"
  assert_successful_code "$output"
}

function bench_bashunit_functional_run() {
  local bench_file=./tests/benchmark/fixtures/bashunit_functional.sh

  local output
  output="$(./bashunit --bench "$bench_file")"
  assert_matches "Benchmark Results" "$output"
  assert_successful_code "$output"
}

function bench_bashunit_default_path() {
  local env_file=./tests/benchmark/fixtures/.env.with_path

  local output
  output="$(./bashunit --bench --env "$env_file")"
  assert_matches "Benchmark Results" "$output"
  assert_successful_code "$output"
}
