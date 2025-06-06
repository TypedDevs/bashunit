#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_runs_benchmark_file() {
  local bench_file=./tests/benchmark/fixtures/bashunit_sleep_bench.sh
  assert_match_snapshot "$(./bashunit --bench --env "$TEST_ENV_FILE" "$bench_file")"
  assert_successful_code "$(./bashunit --bench --env "$TEST_ENV_FILE" "$bench_file")"
}

function test_bashunit_functional_benchmark() {
  local bench_file=./tests/benchmark/fixtures/bashunit_functional_bench.sh
  assert_match_snapshot "$(./bashunit --bench --env "$TEST_ENV_FILE_SIMPLE" "$bench_file")"
  assert_successful_code "$(./bashunit --bench --env "$TEST_ENV_FILE_SIMPLE" "$bench_file")"
}
