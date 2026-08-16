#!/usr/bin/env bash
set -euo pipefail

# --snapshot-report-unused stops halfway: it names the dead snapshots and says
# "delete them yourself", one path at a time. Pruning finishes the job, under
# the same full-run rule -- a subset run resolves a subset of the snapshots,
# and deleting the rest would be data loss dressed as cleanup.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FIXTURES_DIR="$(pwd)/tests/acceptance/fixtures/snapshot_update"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  cp "$FIXTURES_DIR/snap.sh" "$WORKDIR/snap.sh"
  mkdir -p "$WORKDIR/snapshots"
  ALPHA="$WORKDIR/snapshots/snap_sh.test_snapshot_alpha.snapshot"
  BETA="$WORKDIR/snapshots/snap_sh.test_snapshot_beta.snapshot"
  ORPHAN="$WORKDIR/snapshots/snap_sh.test_snapshot_deleted.snapshot"
  echo "alpha value" >"$ALPHA"
  echo "beta value" >"$BETA"
  echo "left behind" >"$ORPHAN"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function run_prune() { # $@ = extra flags
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-prune "$@" snap.sh 2>&1) || true
}

function test_prune_deletes_exactly_what_the_report_lists() {
  local output
  output=$(run_prune)

  assert_file_not_exists "$ORPHAN"
  assert_file_exists "$ALPHA"
  assert_file_exists "$BETA"
  assert_contains "snap_sh.test_snapshot_deleted.snapshot" "$output"
}

function test_prune_prints_every_deleted_path() {
  local output
  output=$(run_prune)

  assert_contains "Deleted" "$output"
  assert_contains "snapshots/snap_sh.test_snapshot_deleted.snapshot" "$output"
}

function test_prune_deletes_nothing_when_no_snapshot_is_unused() {
  rm -f "$ORPHAN"

  local output
  output=$(run_prune)

  assert_file_exists "$ALPHA"
  assert_contains "No unused snapshots" "$output"
}

function test_prune_leaves_a_snapshot_of_a_file_outside_the_run_alone() {
  # The owner has to be on disk for this to be the case the name describes: a
  # file that exists and simply was not selected. This is the guarantee that
  # keeps prune safe on a path subset (#1194).
  echo "" >"$WORKDIR/other_test.sh"
  local foreign="$WORKDIR/snapshots/other_test_sh.test_something.snapshot"
  echo "not mine" >"$foreign"

  run_prune >/dev/null

  assert_file_exists "$foreign"
}

# The kind no run can own: the test file that named it was deleted or renamed,
# so no run will ever discover it and the owner check skipped it forever (#1194).
function test_prune_deletes_a_snapshot_whose_owner_file_is_gone() {
  local gone="$WORKDIR/snapshots/gone_test_sh.test_something.snapshot"
  echo "nobody's" >"$gone"

  local output
  output=$(run_prune)

  assert_file_not_exists "$gone"
  assert_file_exists "$ALPHA"
  assert_file_exists "$BETA"
  assert_contains "gone_test_sh" "$output"
}

# The failing-run gate has to cover the new class too, or a run that never
# reached its assertions would delete what it could not have resolved.
function test_prune_keeps_an_owner_missing_snapshot_when_the_run_fails() {
  local gone="$WORKDIR/snapshots/gone_test_sh.test_something.snapshot"
  echo "nobody's" >"$gone"
  cat >>"$WORKDIR/snap.sh" <<'TEST'

function test_that_fails_too() {
  assert_same "expected" "actual"
}
TEST

  run_prune >/dev/null

  assert_file_exists "$gone"
}

# A failing run may never have reached the assertions that resolve those
# snapshots, so what looks unused might simply not have run.
function test_prune_deletes_nothing_when_the_run_has_failures() {
  cat >>"$WORKDIR/snap.sh" <<'TEST'

function test_that_fails() {
  assert_same "expected" "actual"
}
TEST

  local output
  output=$(run_prune)

  assert_file_exists "$ORPHAN"
  assert_contains "failing" "$output"
}

function test_prune_refuses_to_run_with_filter() {
  local ec=0
  local output
  output=$( (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-prune --filter alpha snap.sh 2>&1) ) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--snapshot-prune needs a full run" "$output"
  assert_file_exists "$ORPHAN"
}

function test_prune_refuses_to_run_with_a_shard() {
  local ec=0
  local output
  output=$( (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-prune --shard 1/2 snap.sh 2>&1) ) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "--snapshot-prune needs a full run" "$output"
  assert_file_exists "$ORPHAN"
}

# Both flags together: update rewrites what the tests resolved, prune removes
# what nothing resolved. They touch disjoint sets.
function test_prune_and_update_together_touch_disjoint_sets() {
  echo "stale" >"$ALPHA"

  run_prune --snapshot-update >/dev/null

  assert_file_not_exists "$ORPHAN"
  assert_file_exists "$ALPHA"
  assert_not_contains "stale" "$(cat "$ALPHA")"
}

function test_prune_works_under_parallel() {
  local output
  output=$( (cd "$WORKDIR" && "$BASHUNIT_BIN" --parallel --skip-env-file \
    --snapshot-prune snap.sh 2>&1) ) || true

  assert_file_not_exists "$ORPHAN"
  assert_file_exists "$ALPHA"
}

function test_no_pruning_without_the_flag() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file snap.sh) >/dev/null 2>&1 || true

  assert_file_exists "$ORPHAN"
}
