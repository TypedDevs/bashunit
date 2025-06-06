#!/usr/bin/env bash

function test_parse_annotations() {
  local script="tests/benchmark/fixtures/bench_bashunit_sleep.bench.sh"
  assert_same "5 2" "$(benchmark::parse_annotations bench_sleep "$script")"
}

function test_run_function_collects_results() {
  source tests/benchmark/fixtures/bench_bashunit_sleep.bench.sh
  _BENCH_NAMES=()
  _BENCH_REVS=()
  _BENCH_ITS=()
  _BENCH_AVERAGES=()

  benchmark::run_function bench_sleep 2 1

  assert_same "bench_sleep" "${_BENCH_NAMES[0]}"
  assert_same "2" "${_BENCH_REVS[0]}"
  assert_same "1" "${_BENCH_ITS[0]}"
  [[ -n "${_BENCH_AVERAGES[0]}" ]]
}
