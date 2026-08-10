#!/usr/bin/env bash
set -euo pipefail

# --order-by reorders the suite, it never narrows it, so every case asserts the
# full selection through --list: same pipeline as a run, exact comparison.

function set_up_before_script() {
  D="./tests/acceptance/fixtures/order_by"
  FIXTURE_A="$D/alpha_fixture.sh"
  FIXTURE_B="$D/beta_fixture.sh"
}

# Runs the two fixtures once so beta's failing test lands in a private cache,
# and echoes the directory holding it. The run is expected to fail.
function _seeded_cache_dir() {
  local dir
  dir="$(bashunit::temp_dir order_by)"
  BASHUNIT_RERUN_CACHE_DIR="$dir/.bashunit" \
    ./bashunit --skip-env-file --no-color --no-parallel "$FIXTURE_A" "$FIXTURE_B" >/dev/null 2>&1 || true
  echo "$dir"
}

function test_order_by_defects_runs_the_recorded_failure_first() {
  local dir
  dir="$(_seeded_cache_dir)"

  local output
  output=$(BASHUNIT_RERUN_CACHE_DIR="$dir/.bashunit" \
    ./bashunit --skip-env-file --list --order-by defects "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)

  assert_same "$FIXTURE_B::test_beta_fails
$FIXTURE_B::test_beta_one
$FIXTURE_A::test_alpha_one
$FIXTURE_A::test_alpha_two" "$output"
}

function test_order_by_defects_keeps_the_whole_suite() {
  local dir
  dir="$(_seeded_cache_dir)"

  local count
  count=$(BASHUNIT_RERUN_CACHE_DIR="$dir/.bashunit" \
    ./bashunit --skip-env-file --list --order-by defects "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null | wc -l)

  assert_same "4" "$(printf '%s' "$count" | tr -d ' ')"
}

function test_rerun_failed_still_narrows_while_order_by_only_orders() {
  local dir
  dir="$(_seeded_cache_dir)"

  local output
  output=$(BASHUNIT_RERUN_CACHE_DIR="$dir/.bashunit" \
    ./bashunit --skip-env-file --list --order-by defects --rerun-failed "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)

  assert_same "$FIXTURE_B::test_beta_fails" "$output"
}

function test_order_by_defects_stops_on_the_known_bad_test_first() {
  local dir
  dir="$(_seeded_cache_dir)"

  local ec=0
  local output
  output=$(BASHUNIT_RERUN_CACHE_DIR="$dir/.bashunit" \
    ./bashunit --skip-env-file --no-color --no-parallel --order-by defects --stop-on-failure \
    "$FIXTURE_A" "$FIXTURE_B" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  # Only the recorded failure ran: without the reordering it would be test 4 of 4.
  assert_contains "Tests: 1 failed, 1 total" "$(printf '%s' "$output" | tr -s ' ')"
}

function test_order_by_defects_without_a_cache_keeps_the_defined_order() {
  local dir
  dir="$(bashunit::temp_dir order_by_empty)"

  local output
  output=$(BASHUNIT_RERUN_CACHE_DIR="$dir/.bashunit" \
    ./bashunit --skip-env-file --list --order-by defects "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)

  assert_same "$FIXTURE_A::test_alpha_one
$FIXTURE_A::test_alpha_two
$FIXTURE_B::test_beta_one
$FIXTURE_B::test_beta_fails" "$output"
}

function test_order_by_defined_is_the_default_order() {
  local plain ordered
  plain=$(./bashunit --skip-env-file --list "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)
  ordered=$(./bashunit --skip-env-file --list --order-by defined "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)

  assert_same "$plain" "$ordered"
}

function test_order_by_random_matches_random_order_for_the_same_seed() {
  local legacy modern
  legacy=$(./bashunit --skip-env-file --list --random-order --seed 42 "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)
  modern=$(./bashunit --skip-env-file --list --order-by random --seed 42 "$FIXTURE_A" "$FIXTURE_B" 2>/dev/null)

  assert_same "$legacy" "$modern"
}

function test_order_by_rejects_an_unknown_mode() {
  local ec=0
  local output
  output=$(./bashunit --skip-env-file --list --order-by sideways "$FIXTURE_A" 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "sideways" "$output"
  assert_contains "defined, defects, random" "$output"
}
