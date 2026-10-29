#!/usr/bin/env bash
# shellcheck disable=SC2317

function set_up() {
  RERUN_TMP_DIR="$(bashunit::temp_dir)/rerun_$$_${RANDOM}"
  mkdir -p "$RERUN_TMP_DIR"
  export BASHUNIT_RERUN_CACHE_DIR="$RERUN_TMP_DIR/.bashunit"
  RERUN_FAILED_OUTPUT_PATH="$RERUN_TMP_DIR/collected"
  RERUN_RAN_OUTPUT_PATH="$RERUN_TMP_DIR/ran"
  : >"$RERUN_FAILED_OUTPUT_PATH"
  : >"$RERUN_RAN_OUTPUT_PATH"
  _BASHUNIT_RERUN_ENTRIES=""
  _BASHUNIT_RERUN_FULL_RUN=false
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
  printf 'tests/a_test.sh:test_one\n' >"$RERUN_RAN_OUTPUT_PATH"

  bashunit::rerun::persist

  assert_empty "$(cat "$cache")"
}

function test_persist_keeps_failures_the_run_did_not_execute() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "${cache%/*}"
  printf 'tests/a_test.sh:test_one\n' >"$cache"
  printf 'tests/b_test.sh:test_two\n' >"$RERUN_RAN_OUTPUT_PATH"

  bashunit::rerun::persist

  assert_same 'tests/a_test.sh:test_one' "$(cat "$cache")"
}

function provide_missing_rerun_execution_metadata() {
  bashunit::data_set empty
  bashunit::data_set unset
  bashunit::data_set missing
}

# @data_provider provide_missing_rerun_execution_metadata
function test_persist_keeps_failures_when_no_tests_ran() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "${cache%/*}"
  printf 'tests/a_test.sh:test_one\n' >"$cache"
  case "$1" in
  unset) unset RERUN_RAN_OUTPUT_PATH ;;
  missing) RERUN_RAN_OUTPUT_PATH="$RERUN_TMP_DIR/missing" ;;
  esac

  bashunit::rerun::persist

  assert_same 'tests/a_test.sh:test_one' "$(cat "$cache")"
}

function test_persist_compares_paths_against_the_launch_directory() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "${cache%/*}"
  printf '%s/tests/a_test.sh:test_one\n' "$BASHUNIT_WORKING_DIR" >"$cache"
  printf 'tests/a_test.sh:test_one\n' >"$RERUN_RAN_OUTPUT_PATH"

  (cd "$RERUN_TMP_DIR" && bashunit::rerun::persist)

  assert_empty "$(cat "$cache")"
}

function test_persist_merges_unexecuted_and_new_failures_in_first_seen_order() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "${cache%/*}"
  printf '%s\n' tests/a_test.sh:test_one tests/b_test.sh:test_two tests/a_test.sh:test_one >"$cache"
  printf '%s\n' tests/a_test.sh:test_one tests/c_test.sh:test_three >"$RERUN_RAN_OUTPUT_PATH"
  printf '%s\n' tests/c_test.sh:test_three tests/c_test.sh:test_three tests/a_test.sh:test_one \
    >"$RERUN_FAILED_OUTPUT_PATH"

  bashunit::rerun::persist

  assert_same $'tests/b_test.sh:test_two\ntests/c_test.sh:test_three\ntests/a_test.sh:test_one' "$(cat "$cache")"
}

function test_persist_ignores_an_unwritable_cache_without_output() {
  local cache output
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "${cache%/*}"
  printf 'tests/a_test.sh:test_one\n' >"$cache"
  printf 'tests/a_test.sh:test_one\n' >"$RERUN_RAN_OUTPUT_PATH"
  chmod 444 "$cache"
  if [ -w "$cache" ]; then
    chmod 644 "$cache"
    bashunit::skip 'the current user can write a 444 file'
    return
  fi

  output=$(bashunit::rerun::persist 2>&1)
  chmod 644 "$cache"

  assert_empty "$output"
  assert_same 'tests/a_test.sh:test_one' "$(cat "$cache")"
}

function test_record_ran_ignores_an_unwritable_collector_without_output() {
  printf blocked >"$RERUN_TMP_DIR/blocked"
  RERUN_RAN_OUTPUT_PATH="$RERUN_TMP_DIR/blocked/ran"
  local output

  output=$(bashunit::rerun::record_ran tests/a_test.sh test_one 2>&1)

  assert_empty "$output"
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

# Writes a cache and loads it, so the ordering tests read as data -> expectation.
function _rerun_cache_with() {
  local cache
  cache="$(bashunit::rerun::cache_file)"
  mkdir -p "$(dirname "$cache")"
  printf '%s' "$1" >"$cache"
  bashunit::rerun::load
}

function test_order_files_puts_recorded_files_first() {
  _rerun_cache_with 'tests/c_test.sh:test_three
tests/a_test.sh:test_one
'

  assert_same "tests/c_test.sh
tests/a_test.sh
tests/b_test.sh" \
    "$(bashunit::rerun::order_files tests/a_test.sh tests/b_test.sh tests/c_test.sh)"
}

function test_order_files_keeps_every_file_exactly_once() {
  _rerun_cache_with 'tests/a_test.sh:test_one
tests/a_test.sh:test_two
'

  assert_same "tests/a_test.sh
tests/b_test.sh" "$(bashunit::rerun::order_files tests/a_test.sh tests/b_test.sh)"
}

function test_order_files_ignores_recorded_files_this_run_did_not_discover() {
  _rerun_cache_with 'tests/gone_test.sh:test_gone
tests/b_test.sh:test_two
'

  assert_same "tests/b_test.sh
tests/a_test.sh" "$(bashunit::rerun::order_files tests/a_test.sh tests/b_test.sh)"
}

function test_order_files_is_a_no_op_without_a_cache() {
  _rerun_cache_with ''

  assert_same "tests/a_test.sh
tests/b_test.sh" "$(bashunit::rerun::order_files tests/a_test.sh tests/b_test.sh)"
}

function test_order_functions_puts_recorded_functions_first_in_recorded_order() {
  _rerun_cache_with 'tests/a_test.sh:test_three
tests/a_test.sh:test_one
'

  assert_same "test_three test_one test_two" \
    "$(bashunit::rerun::order_functions "tests/a_test.sh" "test_one test_two test_three")"
}

function test_order_functions_ignores_entries_recorded_for_another_file() {
  _rerun_cache_with 'tests/b_test.sh:test_two
'

  assert_same "test_one test_two" \
    "$(bashunit::rerun::order_functions "tests/a_test.sh" "test_one test_two")"
}

function test_order_functions_is_a_no_op_without_a_cache() {
  _rerun_cache_with ''

  assert_same "test_one test_two" \
    "$(bashunit::rerun::order_functions "tests/a_test.sh" "test_one test_two")"
}

function provide_full_run_persist_guards() {
  bashunit::data_set 1 ran
  bashunit::data_set 0 empty
}

# @data_provider provide_full_run_persist_guards
function test_full_run_does_not_clear_history_without_successful_execution() {
  mkdir -p "$BASHUNIT_RERUN_CACHE_DIR"
  printf '%s\n' 'deleted_test.sh:test_old' >"$BASHUNIT_RERUN_CACHE_DIR/last-failed"
  _BASHUNIT_RERUN_FULL_RUN=true
  if [ "$2" = ran ]; then
    bashunit::rerun::record_ran tests/pass_test.sh test_pass
  fi
  bashunit::rerun::persist "$1"
  assert_same 'deleted_test.sh:test_old' "$(cat "$BASHUNIT_RERUN_CACHE_DIR/last-failed")"
}
