#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FIXTURES_DIR="$(pwd)/tests/acceptance/fixtures/snapshot_update"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  cp "$FIXTURES_DIR/snap.sh" "$WORKDIR/snap.sh"
  mkdir -p "$WORKDIR/snapshots"
  echo "alpha value" >"$WORKDIR/snapshots/snap_sh.test_snapshot_alpha.snapshot"
  echo "beta value" >"$WORKDIR/snapshots/snap_sh.test_snapshot_beta.snapshot"
  ORPHAN="$WORKDIR/snapshots/snap_sh.test_snapshot_deleted.snapshot"
  echo "left behind" >"$ORPHAN"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function test_reports_the_snapshot_no_test_resolved() {
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused snap.sh 2>&1) || true

  assert_contains "snap_sh.test_snapshot_deleted.snapshot" "$output"
  assert_not_contains "snap_sh.test_snapshot_alpha.snapshot" "$output"
}

function test_reports_nothing_when_every_snapshot_is_used() {
  rm -f "$ORPHAN"

  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused snap.sh 2>&1) || true

  assert_contains "No unused snapshots" "$output"
}

function test_a_snapshot_of_a_test_file_outside_the_run_is_not_reported() {
  # The owner has to be on disk for this to be the case the name describes.
  # Without it the snapshot is an orphan, not a file "outside the run", and the
  # two want opposite answers (#1194).
  echo "" >"$WORKDIR/other_test.sh"
  echo "not mine" >"$WORKDIR/snapshots/other_test_sh.test_something.snapshot"

  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused snap.sh 2>&1) || true

  assert_not_contains "other_test_sh" "$output"
  assert_contains "snap_sh.test_snapshot_deleted.snapshot" "$output"
}

# The kind no run can own: the test file that named it was deleted or renamed,
# so no run will ever discover it and the owner check skipped it forever (#1194).
function test_reports_a_snapshot_whose_owner_file_is_gone() {
  echo "nobody's" >"$WORKDIR/snapshots/gone_test_sh.test_something.snapshot"

  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused snap.sh 2>&1) || true

  assert_contains "gone_test_sh.test_something.snapshot" "$output"
}

function test_the_report_does_not_delete_anything() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused snap.sh) >/dev/null 2>&1 || true

  assert_file_exists "$ORPHAN"
}

function test_no_report_without_the_flag() {
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file snap.sh 2>&1) || true

  assert_not_contains "nused snapshot" "$output"
}

function test_the_flag_is_refused_on_a_partial_run() {
  local code=0
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused --filter alpha snap.sh 2>&1) || code=$?

  assert_same "1" "$code"
  assert_contains "--filter" "$output"
  assert_not_contains "test_snapshot_deleted" "$output"
}

function test_the_flag_is_refused_alongside_a_shard() {
  local code=0
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-report-unused --shard 1/2 snap.sh 2>&1) || code=$?

  assert_same "1" "$code"
  assert_contains "--shard" "$output"
}
