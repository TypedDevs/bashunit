#!/usr/bin/env bash
# shellcheck disable=SC2329 # Mock functions are invoked indirectly by tested code

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

# `@max_ms` accepts decimals (the parse_annotations regex is `[0-9.][0-9.]*`,
# and add_result's own test above stores an avg of "42.5"), but plain `[ -le ]`
# errors on a fractional operand instead of comparing it: the well-under-budget
# row below used to print a stray "integer expression expected" line and always
# fall through to the ">" (failing) branch regardless of the real average (#879).
function test_print_results_outputs_passing_threshold_status_with_decimal_max_ms() {
  function bashunit::env::is_bench_mode_enabled() { return 0; }
  function bashunit::env::is_simple_output_enabled() { return 1; }
  function bashunit::console_results::print_execution_time() { :; }
  function bashunit::print_line() { :; }

  _BASHUNIT_BENCH_NAMES=("fast_fn")
  _BASHUNIT_BENCH_REVS=("1")
  _BASHUNIT_BENCH_ITS=("1")
  _BASHUNIT_BENCH_AVERAGES=("10")
  _BASHUNIT_BENCH_MAX_MILLIS=("100.5")

  local output
  output=$(bashunit::benchmark::print_results 2>&1)

  assert_contains "≤ 100.5" "$output"
  assert_not_contains "integer expression expected" "$output"
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

# A marker that is present but yielded no number is a typo, not an absent
# annotation. Falling back to the default silently ran a different benchmark
# than the one asked for: `@revs=abc` quietly became one revolution (#884).
function test_parse_annotations_rejects_a_malformed_revs() {
  local fixture ec=0
  fixture="$(bashunit::temp_dir)/malformed_bench.sh"
  printf '#!/usr/bin/env bash\n\n# @revs=abc\nfunction bench_x() { :; }\n' >"$fixture"

  local output
  output=$(bashunit::benchmark::parse_annotations bench_x "$fixture" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "@revs" "$output"
}

function test_parse_annotations_rejects_a_malformed_max_ms() {
  local fixture ec=0
  fixture="$(bashunit::temp_dir)/malformed_max_bench.sh"
  printf '#!/usr/bin/env bash\n\n# @max_ms=abc\nfunction bench_x() { :; }\n' >"$fixture"

  local output
  output=$(bashunit::benchmark::parse_annotations bench_x "$fixture" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "@max_ms" "$output"
}

function test_parse_annotations_accepts_a_function_with_no_annotation_at_all() {
  local fixture ec=0
  fixture="$(bashunit::temp_dir)/plain_bench.sh"
  printf '#!/usr/bin/env bash\n\nfunction bench_x() { :; }\n' >"$fixture"

  local output
  output=$(bashunit::benchmark::parse_annotations bench_x "$fixture" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_same "1 1" "$output"
}

function test_stats_to_slots_reports_min_max_and_median_of_an_odd_list() {
  bashunit::benchmark::stats_to_slots "5 1 3"

  assert_same "1.000" "$_BASHUNIT_BENCH_STATS_MIN_OUT"
  assert_same "5.000" "$_BASHUNIT_BENCH_STATS_MAX_OUT"
  assert_same "3.000" "$_BASHUNIT_BENCH_STATS_MEDIAN_OUT"
}

function test_stats_to_slots_averages_the_two_middle_values_of_an_even_list() {
  bashunit::benchmark::stats_to_slots "4 1 3 2"

  assert_same "2.500" "$_BASHUNIT_BENCH_STATS_MEDIAN_OUT"
}

function test_stats_to_slots_keeps_a_dot_decimal_separator_in_any_locale() {
  LC_ALL=es_ES.UTF-8 LC_NUMERIC=es_ES.UTF-8 bashunit::benchmark::stats_to_slots "1.5 2.5"

  assert_same "2.000" "$_BASHUNIT_BENCH_STATS_MEDIAN_OUT"
}

function test_stats_to_slots_leaves_the_slots_empty_for_no_durations() {
  bashunit::benchmark::stats_to_slots ""

  assert_empty "$_BASHUNIT_BENCH_STATS_MIN_OUT"
}
