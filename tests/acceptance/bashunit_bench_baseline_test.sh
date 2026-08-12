#!/usr/bin/env bash

# @max_ms is an absolute ceiling: loose enough to survive the slowest runner,
# so it only catches catastrophes and says nothing about the 30% slowdown that
# stays under it. The baseline compares a run against the previous one.

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
  FIXTURE="$WORKDIR/sample_bench.sh"
  cat >"$FIXTURE" <<'BENCH'
#!/usr/bin/env bash

# @its=1
function bench_one() { sleep "${BENCH_ONE_SLEEP:-0.01}"; }
BENCH
  BASELINE="$WORKDIR/baseline.json"
}

function write_baseline() { # $1 = median to record
  cat >"$BASELINE" <<JSON
{
  "run": { "timestamp": "2026-01-01T00:00:00", "duration_ms": 1, "bashunit_version": "0.0.0",
    "bash_version": "5.0.0", "os": "Linux" },
  "benchmarks": [
    {
      "file": "sample_bench.sh", "function": "bench_one", "name": "Bench one",
      "revs": 1, "its": 1, "iterations_ms": [$1], "average_ms": $1,
      "min_ms": $1, "max_ms": $1, "median_ms": $1,
      "threshold_ms": null, "within_threshold": null
    }
  ]
}
JSON
}

function test_a_run_within_the_tolerance_passes_and_shows_a_delta() {
  # A generous baseline: the run cannot be 10% slower than 10 seconds.
  write_baseline 10000

  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit bench --baseline "$BASELINE" "$FIXTURE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "bench_one" "$output"
  assert_contains "%" "$output"
}

function test_a_regression_beyond_the_tolerance_fails_and_names_the_benchmark() {
  # A baseline of 1ms against a benchmark that sleeps 10ms.
  write_baseline 1

  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit bench --baseline "$BASELINE" "$FIXTURE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "bench_one" "$output"
  assert_contains "regression" "$output"
}

function test_the_tolerance_is_overridable() {
  write_baseline 1

  local ec=0
  # 100000% of 1ms is 1 second: the same run that fails at the default passes.
  NO_COLOR=1 ./bashunit bench --baseline "$BASELINE" --baseline-tolerance 100000 \
    "$FIXTURE" >/dev/null 2>&1 || ec=$?

  assert_successful_code "" "" "$ec"
}

function test_a_benchmark_missing_from_the_baseline_is_new_not_a_failure() {
  write_baseline 10000
  cat >>"$FIXTURE" <<'BENCH'

# @its=1
function bench_added_later() { :; }
BENCH

  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit bench --baseline "$BASELINE" "$FIXTURE" 2>&1) || ec=$?

  assert_successful_code "" "" "$ec"
  assert_contains "new" "$output"
  assert_contains "bench_added_later" "$output"
}

function test_a_benchmark_only_in_the_baseline_is_reported_as_removed() {
  cat >"$BASELINE" <<'JSON'
{
  "run": { "timestamp": "2026-01-01T00:00:00", "duration_ms": 1, "bashunit_version": "0.0.0",
    "bash_version": "5.0.0", "os": "Linux" },
  "benchmarks": [
    { "file": "x.sh", "function": "bench_one", "name": "Bench one", "revs": 1, "its": 1,
      "iterations_ms": [10000], "average_ms": 10000, "min_ms": 10000, "max_ms": 10000,
      "median_ms": 10000, "threshold_ms": null, "within_threshold": null },
    { "file": "x.sh", "function": "bench_gone", "name": "Bench gone", "revs": 1, "its": 1,
      "iterations_ms": [1], "average_ms": 1, "min_ms": 1, "max_ms": 1,
      "median_ms": 1, "threshold_ms": null, "within_threshold": null }
  ]
}
JSON

  local output
  output=$(NO_COLOR=1 ./bashunit bench --baseline "$BASELINE" "$FIXTURE" 2>&1) || true

  assert_contains "removed" "$output"
  assert_contains "bench_gone" "$output"
}

function test_an_unreadable_baseline_exits_non_zero() {
  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit bench --baseline "$WORKDIR/not-here.json" "$FIXTURE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "baseline" "$output"
}

function test_a_malformed_baseline_exits_non_zero_instead_of_passing() {
  printf 'this is not json\n' >"$BASELINE"

  local ec=0
  local output
  output=$(NO_COLOR=1 ./bashunit bench --baseline "$BASELINE" "$FIXTURE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "baseline" "$output"
}

# The round trip is the whole workflow: record a baseline today, compare
# against it tomorrow.
function test_baseline_update_writes_a_file_a_later_baseline_accepts() {
  local recorded="$WORKDIR/recorded.json"

  ./bashunit bench --baseline-update "$recorded" "$FIXTURE" >/dev/null 2>&1 || true
  assert_file_exists "$recorded"

  local ec=0
  NO_COLOR=1 ./bashunit bench --baseline "$recorded" --baseline-tolerance 100000 \
    "$FIXTURE" >/dev/null 2>&1 || ec=$?

  assert_successful_code "" "" "$ec"
}

function test_the_flags_are_advertised_by_bench_help() {
  local output
  output=$(./bashunit bench --help 2>&1)

  assert_contains "--baseline" "$output"
  assert_contains "--baseline-tolerance" "$output"
  assert_contains "--baseline-update" "$output"
}
