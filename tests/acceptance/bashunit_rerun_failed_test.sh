#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FIXTURES_DIR="$(pwd)/tests/acceptance/fixtures/rerun"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  cp "$FIXTURES_DIR/mixed.sh" "$WORKDIR/mixed.sh"
  cp "$FIXTURES_DIR/all_pass.sh" "$WORKDIR/all_pass.sh"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function test_failing_run_records_only_failing_tests_to_cache() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file mixed.sh) >/dev/null 2>&1 || true

  local cache="$WORKDIR/.bashunit/last-failed"
  assert_file_exists "$cache"
  assert_same "mixed.sh:test_rerun_beta_fails" "$(cat "$cache")"
}

function test_rerun_failed_replays_only_the_failing_test() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file mixed.sh) >/dev/null 2>&1 || true

  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file --rerun-failed mixed.sh 2>&1) || true

  assert_contains "1 total" "$output"
  assert_contains "beta" "$output"
  assert_not_contains "alpha" "$output"
  assert_not_contains "gamma" "$output"
}

function provide_rerun_execution_modes() {
  bashunit::data_set --no-parallel
  bashunit::data_set --parallel
}

# @data_provider provide_rerun_execution_modes
function test_green_file_subset_preserves_failures_and_rerun_replays_them() {
  local mode="$1" output
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file mixed.sh) >/dev/null 2>&1 || true
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file all_pass.sh) >/dev/null 2>&1

  assert_same 'mixed.sh:test_rerun_beta_fails' "$(cat "$WORKDIR/.bashunit/last-failed")"
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file --rerun-failed mixed.sh all_pass.sh 2>&1) || true
  assert_contains '1 total' "$output"
  assert_contains beta "$output"
  assert_not_contains 'running the full suite' "$output"
}

# @data_provider provide_rerun_execution_modes
function test_green_filter_subset_preserves_unselected_failures() {
  local mode="$1"
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file mixed.sh) >/dev/null 2>&1 || true
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file --filter alpha mixed.sh) >/dev/null 2>&1

  assert_same 'mixed.sh:test_rerun_beta_fails' "$(cat "$WORKDIR/.bashunit/last-failed")"
}

# @data_provider provide_rerun_execution_modes
function test_green_full_run_clears_executed_failures() {
  local mode="$1" contents
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file mixed.sh all_pass.sh) >/dev/null 2>&1 || true
  contents=$(cat "$WORKDIR/mixed.sh")
  printf '%s\n' "${contents/actual/expected}" >"$WORKDIR/mixed.sh"
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file mixed.sh all_pass.sh) >/dev/null 2>&1

  assert_empty "$(cat "$WORKDIR/.bashunit/last-failed")"
}

function provide_rerun_alternate_paths() {
  bashunit::data_set --no-parallel ./mixed.sh
  bashunit::data_set --parallel ./mixed.sh
  bashunit::data_set --no-parallel absolute
  bashunit::data_set --parallel absolute
}

# @data_provider provide_rerun_alternate_paths
function test_green_run_clears_an_executed_failure_with_an_alternate_path() {
  local mode="$1" path="$2" contents
  if [ "$path" = absolute ]; then
    path="$WORKDIR/mixed.sh"
  fi
  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file mixed.sh) >/dev/null 2>&1 || true
  contents=$(cat "$WORKDIR/mixed.sh")
  printf '%s\n' "${contents/actual/expected}" >"$WORKDIR/mixed.sh"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" "$mode" --skip-env-file "$path") >/dev/null 2>&1

  assert_empty "$(cat "$WORKDIR/.bashunit/last-failed")"
}

function provide_rerun_full_scopes() {
  bashunit::data_set --no-parallel default renamed
  bashunit::data_set --parallel default renamed
  bashunit::data_set --no-parallel root deleted
  bashunit::data_set --parallel root deleted
  bashunit::data_set --no-parallel directory renamed
  bashunit::data_set --parallel directory renamed
}

# @data_provider provide_rerun_full_scopes
function test_green_full_scope_clears_stale_failures() {
  local mode="$1" scope="$2" stale="$3" contents
  mkdir "$WORKDIR/tests"
  cp "$WORKDIR/mixed.sh" "$WORKDIR/tests/mixed_test.sh"
  cp "$WORKDIR/all_pass.sh" "$WORKDIR/tests/pass_test.sh"
  (cd "$WORKDIR" && BASHUNIT_DEFAULT_PATH=tests "$BASHUNIT_BIN" "$mode" --skip-env-file) >/dev/null 2>&1 || true
  assert_not_empty "$(cat "$WORKDIR/.bashunit/last-failed")"
  if [ "$stale" = deleted ]; then
    rm "$WORKDIR/tests/mixed_test.sh"
  else
    contents=$(cat "$WORKDIR/tests/mixed_test.sh")
    contents=${contents/actual/expected}
    printf '%s\n' "${contents/test_rerun_beta_fails/test_rerun_beta_renamed}" >"$WORKDIR/tests/mixed_test.sh"
  fi
  case "$scope" in
  default)
    (cd "$WORKDIR" && BASHUNIT_DEFAULT_PATH=tests "$BASHUNIT_BIN" "$mode" --skip-env-file) >/dev/null 2>&1
    ;;
  root)
    (cd "$WORKDIR" && BASHUNIT_DEFAULT_PATH=tests "$BASHUNIT_BIN" "$mode" --skip-env-file "$WORKDIR") >/dev/null 2>&1
    ;;
  directory)
    (cd "$WORKDIR" && BASHUNIT_DEFAULT_PATH=tests "$BASHUNIT_BIN" "$mode" --skip-env-file ./tests) >/dev/null 2>&1
    ;;
  esac
  assert_empty "$(cat "$WORKDIR/.bashunit/last-failed")"
}

function provide_rerun_incomplete_full_scopes() {
  bashunit::data_set --filter alpha
  bashunit::data_set --exclude-filter beta
  bashunit::data_set --tag selected
  bashunit::data_set --exclude-tag absent
  bashunit::data_set --shard 1/1
  bashunit::data_set --rerun-failed ''
}

# @data_provider provide_rerun_incomplete_full_scopes
function test_selected_root_preserves_stale_failures() {
  mkdir -p "$WORKDIR/.bashunit" "$WORKDIR/tests"
  cp "$WORKDIR/all_pass.sh" "$WORKDIR/tests/pass_test.sh"
  printf '%s\n' 'deleted_test.sh:test_old' >"$WORKDIR/.bashunit/last-failed"
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --pass-with-no-tests "$1" ${2:+"$2"} .) >/dev/null 2>&1 || true
  assert_same 'deleted_test.sh:test_old' "$(cat "$WORKDIR/.bashunit/last-failed")"
}

function test_partial_directory_preserves_stale_failures() {
  mkdir -p "$WORKDIR/.bashunit" "$WORKDIR/tests/subset"
  cp "$WORKDIR/all_pass.sh" "$WORKDIR/tests/subset/pass_test.sh"
  printf '%s\n' 'deleted_test.sh:test_old' >"$WORKDIR/.bashunit/last-failed"
  (cd "$WORKDIR" && BASHUNIT_DEFAULT_PATH=tests "$BASHUNIT_BIN" \
    --no-parallel --skip-env-file tests/subset) >/dev/null 2>&1
  assert_same 'deleted_test.sh:test_old' "$(cat "$WORKDIR/.bashunit/last-failed")"
}

function test_full_scope_with_no_tests_preserves_stale_failures() {
  mkdir -p "$WORKDIR/.bashunit" "$WORKDIR/empty"
  printf '%s\n' 'deleted_test.sh:test_old' >"$WORKDIR/.bashunit/last-failed"
  (cd "$WORKDIR" && BASHUNIT_DEFAULT_PATH=empty "$BASHUNIT_BIN" \
    --no-parallel --skip-env-file --pass-with-no-tests empty) >/dev/null 2>&1
  assert_same 'deleted_test.sh:test_old' "$(cat "$WORKDIR/.bashunit/last-failed")"
}

function test_rerun_failed_without_cache_runs_full_suite_with_notice() {
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file --rerun-failed all_pass.sh 2>&1) || true

  assert_contains "running the full suite" "$output"
  assert_contains "2 total" "$output"
}

function test_rerun_failed_intersects_with_filter() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file mixed.sh) >/dev/null 2>&1 || true

  # Only beta is cached; a --filter for a passing test intersects to nothing.
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --rerun-failed --filter alpha mixed.sh 2>&1) || true

  assert_not_contains "beta" "$output"
}

function test_parallel_run_records_failing_tests_to_cache() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --parallel --skip-env-file mixed.sh) >/dev/null 2>&1 || true

  local cache="$WORKDIR/.bashunit/last-failed"
  assert_file_exists "$cache"
  assert_same "mixed.sh:test_rerun_beta_fails" "$(cat "$cache")"
}
