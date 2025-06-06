#!/usr/bin/env bash

function set_up() {
  SCRIPT="tests/benchmark/fixtures/bashunit_sleep_bench.sh"
}

function test_parse_annotations() {
  assert_same "5 2" "$(benchmark::parse_annotations bench_sleep "$SCRIPT")"
}

function test_parse_annotations_with_synonyms() {
  assert_same "3 2" "$(benchmark::parse_annotations bench_sleep_synonym "$SCRIPT")"
}

function test_run_function_collects_results() {
  # shellcheck disable=SC1090
  source "$SCRIPT"

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
