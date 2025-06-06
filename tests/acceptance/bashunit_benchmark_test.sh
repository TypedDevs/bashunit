#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_runs_benchmark_file() {
  skip "we need custom placeholders on snapshot first" && return
  local bench_file=./tests/benchmark/fixtures/bench_bashunit_sleep.bench.sh
  assert_match_snapshot "$(./bashunit --bench --env "$TEST_ENV_FILE" "$bench_file")"
  assert_successful_code "$(./bashunit --bench --env "$TEST_ENV_FILE" "$bench_file")"
}

function test_bashunit_runs_benchmark_from_default_path() {
  skip "we need custom placeholders on snapshot first" && return
  local env_file=./tests/benchmark/fixtures/.env.with_path
  assert_match_snapshot "$(./bashunit --bench --env "$env_file")"
  assert_successful_code "$(./bashunit --bench --env "$env_file")"
}

function test_bashunit_functional_benchmark() {
  skip "we need custom placeholders on snapshot first" && return
  local bench_file=./tests/benchmark/fixtures/bench_bashunit_functional.bench.sh
  assert_match_snapshot "$(./bashunit --bench --env "$TEST_ENV_FILE_SIMPLE" "$bench_file")"
  assert_successful_code "$(./bashunit --bench --env "$TEST_ENV_FILE_SIMPLE" "$bench_file")"
}
