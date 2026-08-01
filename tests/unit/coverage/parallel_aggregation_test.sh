#!/usr/bin/env bash
# shellcheck disable=SC2317

# Parallel coverage aggregation tests.
# When tests run in parallel, each worker writes to a per-PID file
# alongside the canonical data file (e.g. hits.dat.12345). The
# aggregate_parallel function is responsible for merging those into the
# canonical files at end-of-run and deduplicating the tracked-files
# index.

_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE_TEST_HITS_FILE=""
_ORIG_COVERAGE=""

function set_up() {
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE_TEST_HITS_FILE="$_BASHUNIT_COVERAGE_TEST_HITS_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"

  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  _BASHUNIT_COVERAGE_TEST_HITS_FILE=""
  export BASHUNIT_COVERAGE="true"
}

function tear_down() {
  if [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ] &&
    [ "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  _BASHUNIT_COVERAGE_TEST_HITS_FILE="$_ORIG_COVERAGE_TEST_HITS_FILE"

  if [ -n "$_ORIG_COVERAGE" ]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
}

function test_aggregate_parallel_merges_hits_from_per_pid_files() {
  bashunit::coverage::init

  # Simulate two worker PIDs each having written their own hits file
  echo "/path/to/file.sh:5" >"${_BASHUNIT_COVERAGE_DATA_FILE}.111"
  printf '/path/to/file.sh:5\n/path/to/file.sh:7\n' \
    >"${_BASHUNIT_COVERAGE_DATA_FILE}.222"

  bashunit::coverage::aggregate_parallel

  local merged
  merged=$(cat "$_BASHUNIT_COVERAGE_DATA_FILE")

  assert_contains "/path/to/file.sh:5" "$merged"
  assert_contains "/path/to/file.sh:7" "$merged"

  # Per-PID files removed after merge
  assert_file_not_exists "${_BASHUNIT_COVERAGE_DATA_FILE}.111"
  assert_file_not_exists "${_BASHUNIT_COVERAGE_DATA_FILE}.222"
}

function test_aggregate_parallel_dedupes_tracked_files() {
  bashunit::coverage::init

  # Two workers tracked the same file; aggregation must keep one entry
  printf '/path/to/file.sh\n/path/to/other.sh\n' \
    >"${_BASHUNIT_COVERAGE_TRACKED_FILES}.111"
  printf '/path/to/file.sh\n/path/to/third.sh\n' \
    >"${_BASHUNIT_COVERAGE_TRACKED_FILES}.222"

  bashunit::coverage::aggregate_parallel

  local entries
  entries=$(wc -l <"$_BASHUNIT_COVERAGE_TRACKED_FILES" | tr -d ' ')

  # Three unique paths despite duplicate file.sh entries
  assert_equals "3" "$entries"
}

function test_aggregate_parallel_merges_test_hits_files() {
  bashunit::coverage::init

  echo "/src/a.sh:10|tests/x_test.sh:test_one" \
    >"${_BASHUNIT_COVERAGE_TEST_HITS_FILE}.111"
  echo "/src/a.sh:10|tests/y_test.sh:test_two" \
    >"${_BASHUNIT_COVERAGE_TEST_HITS_FILE}.222"

  bashunit::coverage::aggregate_parallel

  local content
  content=$(cat "$_BASHUNIT_COVERAGE_TEST_HITS_FILE")

  assert_contains "test_one" "$content"
  assert_contains "test_two" "$content"
}

function test_aggregate_parallel_is_a_noop_when_no_per_pid_files_exist() {
  bashunit::coverage::init

  echo "/already-merged.sh:1" >"$_BASHUNIT_COVERAGE_DATA_FILE"

  bashunit::coverage::aggregate_parallel

  local content
  content=$(cat "$_BASHUNIT_COVERAGE_DATA_FILE")

  assert_equals "/already-merged.sh:1" "$content"
}

function test_aggregate_parallel_handles_empty_per_pid_file() {
  bashunit::coverage::init

  : >"${_BASHUNIT_COVERAGE_DATA_FILE}.999"

  bashunit::coverage::aggregate_parallel

  # Empty file aggregated and removed without error
  assert_file_not_exists "${_BASHUNIT_COVERAGE_DATA_FILE}.999"
}
