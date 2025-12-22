#!/usr/bin/env bash

function set_up_before_script() {
  source "$BASHUNIT_ROOT_DIR/src/benchmark.sh"
}

function set_up() {
  SCRIPT="tests/benchmark/fixtures/bashunit_sleep_bench.sh"
}

function test_parse_annotations() {
  assert_same "5 2 25" "$(bashunit::benchmark::parse_annotations bench_sleep "$SCRIPT")"
}

function test_parse_annotations_with_synonyms() {
  assert_same "3 2" "$(bashunit::benchmark::parse_annotations bench_sleep_synonym "$SCRIPT")"
}

function test_run_function_collects_results() {
  # shellcheck disable=SC1090
  source "$SCRIPT"

  _BASHUNIT_BENCH_NAMES=()
  _BASHUNIT_BENCH_REVS=()
  _BASHUNIT_BENCH_ITS=()
  _BASHUNIT_BENCH_AVERAGES=()

  bashunit::benchmark::run_function bench_sleep 2 1 ""

  assert_same "bench_sleep" "${_BASHUNIT_BENCH_NAMES[0]}"
  assert_same "2" "${_BASHUNIT_BENCH_REVS[0]}"
  assert_same "1" "${_BASHUNIT_BENCH_ITS[0]}"
  [[ -n "${_BASHUNIT_BENCH_AVERAGES[0]}" ]]
}

# Parse annotations edge cases

function test_parse_annotations_returns_defaults_when_no_annotations() {
  assert_same "1 1" "$(bashunit::benchmark::parse_annotations bench_no_annotations "$SCRIPT")"
}

function test_parse_annotations_with_only_revs() {
  assert_same "10 1" "$(bashunit::benchmark::parse_annotations bench_only_revs "$SCRIPT")"
}

function test_parse_annotations_with_only_its() {
  assert_same "1 5" "$(bashunit::benchmark::parse_annotations bench_only_its "$SCRIPT")"
}

function test_parse_annotations_with_only_max_ms() {
  assert_same "1 1 100" "$(bashunit::benchmark::parse_annotations bench_only_max_ms "$SCRIPT")"
}

# Add result tests

function test_add_result_appends_to_arrays() {
  _BASHUNIT_BENCH_NAMES=()
  _BASHUNIT_BENCH_REVS=()
  _BASHUNIT_BENCH_ITS=()
  _BASHUNIT_BENCH_AVERAGES=()
  _BASHUNIT_BENCH_MAX_MILLIS=()

  bashunit::benchmark::add_result "test_fn" "5" "3" "42.5" "100"

  assert_same "test_fn" "${_BASHUNIT_BENCH_NAMES[0]}"
  assert_same "5" "${_BASHUNIT_BENCH_REVS[0]}"
  assert_same "3" "${_BASHUNIT_BENCH_ITS[0]}"
  assert_same "42.5" "${_BASHUNIT_BENCH_AVERAGES[0]}"
  assert_same "100" "${_BASHUNIT_BENCH_MAX_MILLIS[0]}"
}

function test_add_result_handles_empty_max_ms() {
  _BASHUNIT_BENCH_NAMES=()
  _BASHUNIT_BENCH_REVS=()
  _BASHUNIT_BENCH_ITS=()
  _BASHUNIT_BENCH_AVERAGES=()
  _BASHUNIT_BENCH_MAX_MILLIS=()

  bashunit::benchmark::add_result "test_fn" "2" "1" "10.0" ""

  assert_same "test_fn" "${_BASHUNIT_BENCH_NAMES[0]}"
  assert_same "" "${_BASHUNIT_BENCH_MAX_MILLIS[0]}"
}

# Print results tests

function test_print_results_returns_early_when_bench_mode_disabled() {
  function bashunit::env::is_bench_mode_enabled() { return 1; }

  _BASHUNIT_BENCH_NAMES=("test_fn")
  local output
  output=$(bashunit::benchmark::print_results)

  assert_empty "$output"
}

function test_print_results_returns_early_when_no_results() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }

  _BASHUNIT_BENCH_NAMES=()
  local output
  output=$(bashunit::benchmark::print_results)

  assert_empty "$output"
}

function test_print_results_outputs_header_without_threshold() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 1; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("test_fn")
  _BASHUNIT_BENCH_REVS=("2")
  _BASHUNIT_BENCH_ITS=("1")
  _BASHUNIT_BENCH_AVERAGES=("10")
  _BASHUNIT_BENCH_MAX_MILLIS=("")

  local output
  output=$(bashunit::benchmark::print_results)

  assert_contains "Benchmark Results" "$output"
  assert_contains "Name" "$output"
  assert_contains "Revs" "$output"
  assert_contains "Its" "$output"
  assert_contains "Avg(ms)" "$output"
  assert_not_contains "Status" "$output"
}

function test_print_results_outputs_header_with_threshold() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 1; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("test_fn")
  _BASHUNIT_BENCH_REVS=("2")
  _BASHUNIT_BENCH_ITS=("1")
  _BASHUNIT_BENCH_AVERAGES=("10")
  _BASHUNIT_BENCH_MAX_MILLIS=("100")

  local output
  output=$(bashunit::benchmark::print_results)

  assert_contains "Status" "$output"
}

function test_print_results_outputs_row_without_threshold() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 1; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("my_test")
  _BASHUNIT_BENCH_REVS=("5")
  _BASHUNIT_BENCH_ITS=("3")
  _BASHUNIT_BENCH_AVERAGES=("25")
  _BASHUNIT_BENCH_MAX_MILLIS=("")

  local output
  output=$(bashunit::benchmark::print_results)

  assert_contains "my_test" "$output"
  assert_contains "5" "$output"
  assert_contains "3" "$output"
  assert_contains "25" "$output"
}

function test_print_results_outputs_passing_threshold_status() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 1; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("fast_fn")
  _BASHUNIT_BENCH_REVS=("1")
  _BASHUNIT_BENCH_ITS=("1")
  _BASHUNIT_BENCH_AVERAGES=("10")
  _BASHUNIT_BENCH_MAX_MILLIS=("100")

  local output
  output=$(bashunit::benchmark::print_results)

  assert_contains "≤ 100" "$output"
}

function test_print_results_outputs_failing_threshold_status() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 1; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("slow_fn")
  _BASHUNIT_BENCH_REVS=("1")
  _BASHUNIT_BENCH_ITS=("1")
  _BASHUNIT_BENCH_AVERAGES=("200")
  _BASHUNIT_BENCH_MAX_MILLIS=("100")

  local output
  output=$(bashunit::benchmark::print_results)

  assert_contains "> 100" "$output"
}

function test_print_results_adds_newline_in_simple_mode() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 0; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("test_fn")
  _BASHUNIT_BENCH_REVS=("1")
  _BASHUNIT_BENCH_ITS=("1")
  _BASHUNIT_BENCH_AVERAGES=("10")
  _BASHUNIT_BENCH_MAX_MILLIS=("")

  local output
  output=$(bashunit::benchmark::print_results)

  # Simple mode adds an extra newline at the start
  assert_contains "Benchmark Results" "$output"
}

# Run function additional tests

function test_run_function_stores_max_ms() {
  # shellcheck disable=SC1090
  source "$SCRIPT"

  _BASHUNIT_BENCH_NAMES=()
  _BASHUNIT_BENCH_REVS=()
  _BASHUNIT_BENCH_ITS=()
  _BASHUNIT_BENCH_AVERAGES=()
  _BASHUNIT_BENCH_MAX_MILLIS=()

  bashunit::benchmark::run_function bench_sleep 1 1 "50"

  assert_same "50" "${_BASHUNIT_BENCH_MAX_MILLIS[0]}"
}

function test_run_function_with_multiple_iterations() {
  # shellcheck disable=SC1090
  source "$SCRIPT"

  _BASHUNIT_BENCH_NAMES=()
  _BASHUNIT_BENCH_REVS=()
  _BASHUNIT_BENCH_ITS=()
  _BASHUNIT_BENCH_AVERAGES=()
  _BASHUNIT_BENCH_MAX_MILLIS=()

  bashunit::benchmark::run_function bench_sleep 1 3 ""

  assert_same "bench_sleep" "${_BASHUNIT_BENCH_NAMES[0]}"
  assert_same "3" "${_BASHUNIT_BENCH_ITS[0]}"
  [[ -n "${_BASHUNIT_BENCH_AVERAGES[0]}" ]]
}
