#!/usr/bin/env bash
# shellcheck disable=SC2317

function set_up() {
  RERUN_TMP_DIR="$(bashunit::temp_dir)/rerun_$$_${RANDOM}"
  mkdir -p "$RERUN_TMP_DIR"
  export BASHUNIT_RERUN_CACHE_DIR="$RERUN_TMP_DIR/.bashunit"
  RERUN_FAILED_OUTPUT_PATH="$RERUN_TMP_DIR/collected"
  : >"$RERUN_FAILED_OUTPUT_PATH"
  _BASHUNIT_RERUN_ENTRIES=""
}

function tear_down() {
  rm -rf "$RERUN_TMP_DIR"
  unset BASHUNIT_RERUN_CACHE_DIR
  unset BASHUNIT_RERUN_FAILED
}

function test_cache_file_defaults_under_dot_bashunit() {
  unset BASHUNIT_RERUN_CACHE_DIR
  assert_same ".bashunit/last-failed" "$(bashunit::rerun::cache_file)"
}

function test_cache_file_honours_override_dir() {
  assert_same "$RERUN_TMP_DIR/.bashunit/last-failed" "$(bashunit::rerun::cache_file)"
}

function test_is_enabled_reflects_env_flag() {
  export BASHUNIT_RERUN_FAILED=true
  local rc=0
  bashunit::rerun::is_enabled || rc=$?
  assert_same 0 "$rc"

  export BASHUNIT_RERUN_FAILED=false
  rc=0
  bashunit::rerun::is_enabled || rc=$?
  assert_same 1 "$rc"
}

function test_persist_writes_deduped_entries_to_cache() {
  printf '%s\n' \
    "tests/a_test.sh:test_one" \
    "tests/a_test.sh:test_one" \
    "tests/b_test.sh:test_two" >"$RERUN_FAILED_OUTPUT_PATH"

  bashunit::rerun::persist

  local cache
  cache="$(bashunit::rerun::cache_file)"
  assert_file_exists "$cache"
  assert_same "tests/a_test.sh:test_one
tests/b_test.sh:test_two" "$(cat "$cache")"
}

function test_persist_truncates_cache_on_green_run() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "$(dirname "$cache")"
  printf 'tests/a_test.sh:test_one\n' >"$cache"

  : >"$RERUN_FAILED_OUTPUT_PATH" # no failures collected

  bashunit::rerun::persist

  assert_empty "$(cat "$cache")"
}

function test_load_and_has_entries() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "$(dirname "$cache")"
  printf 'tests/a_test.sh:test_one\ntests/b_test.sh:test_two\n' >"$cache"

  bashunit::rerun::load

  local rc=0
  bashunit::rerun::has_entries || rc=$?
  assert_same 0 "$rc"
}

function test_has_entries_false_when_cache_missing() {
  bashunit::rerun::load
  local rc=0
  bashunit::rerun::has_entries || rc=$?
  assert_same 1 "$rc"
}

function test_files_returns_distinct_test_files() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "$(dirname "$cache")"
  printf 'tests/a_test.sh:test_one\ntests/a_test.sh:test_two\ntests/b_test.sh:test_three\n' >"$cache"

  bashunit::rerun::load

  assert_same "tests/a_test.sh
tests/b_test.sh" "$(bashunit::rerun::files)"
}

function test_allows_only_recorded_pairs() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "$(dirname "$cache")"
  printf 'tests/a_test.sh:test_one\n' >"$cache"

  bashunit::rerun::load

  local rc=0
  bashunit::rerun::allows "tests/a_test.sh" "test_one" || rc=$?
  assert_same 0 "$rc"

  rc=0
  bashunit::rerun::allows "tests/a_test.sh" "test_other" || rc=$?
  assert_same 1 "$rc"
}

function test_filter_functions_keeps_only_allowed() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "$(dirname "$cache")"
  printf 'tests/a_test.sh:test_one\ntests/a_test.sh:test_three\n' >"$cache"

  bashunit::rerun::load

  assert_same "test_one test_three" \
    "$(bashunit::rerun::filter_functions "tests/a_test.sh" "test_one test_two test_three")"
}
