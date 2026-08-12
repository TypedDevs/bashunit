#!/usr/bin/env bash

# `bashunit bench` printed a table and threw it away: nothing to store as a CI
# artifact, nothing to chart, nothing for a later run to compare against.

function set_up() {
  FIXTURE_DIR="$(bashunit::temp_dir)"
  FIXTURE="$FIXTURE_DIR/sample_bench.sh"
  cat >"$FIXTURE" <<'BENCH'
#!/usr/bin/env bash

# The markers live on ONE line: parse_annotations reads the single line above
# the definition.
# @revs=2 @its=2
function bench_fast() { :; }

# @its=1 @max_ms=1
function bench_slow() { sleep 0.05; }
BENCH
  JQ_AVAILABLE=false
  { command -v jq >/dev/null 2>&1 && JQ_AVAILABLE=true; } || true
}

function test_report_json_is_valid_and_lists_every_benchmark_once() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(bashunit::temp_file)"

  ./bashunit bench --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_successful_code "$(jq empty "$report" 2>&1)"
  assert_same "2" "$(jq '.benchmarks | length' "$report")"
  assert_same "1" "$(jq '[.benchmarks[] | select(.function == "bench_fast")] | length' "$report")"
}

function test_report_json_carries_the_revs_its_and_timings() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(bashunit::temp_file)"

  ./bashunit bench --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_same "2" "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .revs' "$report")"
  assert_same "2" "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .its' "$report")"
  assert_same "2" "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .iterations_ms | length' "$report")"
  assert_not_empty "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .average_ms' "$report")"
  assert_not_empty "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .min_ms' "$report")"
  assert_not_empty "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .max_ms' "$report")"
  assert_not_empty "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .median_ms' "$report")"
}

function test_report_json_carries_the_threshold_and_its_verdict() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(bashunit::temp_file)"

  ./bashunit bench --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_same "1" "$(jq -r '.benchmarks[] | select(.function == "bench_slow") | .threshold_ms' "$report")"
  assert_same "false" "$(jq -r '.benchmarks[] | select(.function == "bench_slow") | .within_threshold' "$report")"
  assert_same "null" "$(jq -r '.benchmarks[] | select(.function == "bench_fast") | .threshold_ms' "$report")"
}

function test_report_json_carries_run_level_metadata() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report
  report="$(bashunit::temp_file)"

  ./bashunit bench --report-json "$report" "$FIXTURE" >/dev/null 2>&1 || true

  assert_not_empty "$(jq -r '.run.timestamp' "$report")"
  assert_not_empty "$(jq -r '.run.duration_ms' "$report")"
  assert_not_empty "$(jq -r '.run.bashunit_version' "$report")"
  assert_not_empty "$(jq -r '.run.bash_version' "$report")"
  assert_not_empty "$(jq -r '.run.os' "$report")"
}

function test_the_reported_average_matches_the_console() {
  if [ "$JQ_AVAILABLE" = false ]; then bashunit::skip "jq required"; return; fi
  local report output
  report="$(bashunit::temp_file)"

  output=$(NO_COLOR=1 ./bashunit bench --report-json "$report" "$FIXTURE" 2>&1) || true

  local reported
  reported="$(jq -r '.benchmarks[] | select(.function == "bench_slow") | .average_ms' "$report")"
  assert_contains "$reported" "$output"
}

function test_report_junit_produces_a_testsuite_per_run() {
  local report
  report="$(bashunit::temp_file)"

  ./bashunit bench --report-junit "$report" "$FIXTURE" >/dev/null 2>&1 || true

  local xml
  xml="$(cat "$report")"
  assert_contains '<?xml version="1.0" encoding="UTF-8"?>' "$xml"
  assert_contains "<testsuites" "$xml"
  assert_contains 'tests="2"' "$xml"
  assert_contains 'name="Bench fast"' "$xml"
}

# A benchmark over its @max_ms is the failure a CI reporter must show.
function test_report_junit_marks_a_benchmark_over_its_threshold_as_failed() {
  local report
  report="$(bashunit::temp_file)"

  ./bashunit bench --report-junit "$report" "$FIXTURE" >/dev/null 2>&1 || true

  local xml
  xml="$(cat "$report")"
  assert_contains 'failures="1"' "$xml"
  assert_contains "<failure" "$xml"
}

function test_an_unwritable_report_path_fails_fast() {
  local ec=0
  local output
  output=$(./bashunit bench --report-json /nope/does/not/exist/r.json "$FIXTURE" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "cannot be written" "$output"
}

function test_the_flags_are_advertised_by_bench_help() {
  local output
  output=$(./bashunit bench --help 2>&1)

  assert_contains "--report-json" "$output"
  assert_contains "--report-junit" "$output"
}
