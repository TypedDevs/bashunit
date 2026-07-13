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

function test_green_run_clears_the_cache() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file mixed.sh) >/dev/null 2>&1 || true
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file all_pass.sh) >/dev/null 2>&1 || true

  assert_empty "$(cat "$WORKDIR/.bashunit/last-failed")"
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
