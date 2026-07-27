#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FIXTURES_DIR="$(pwd)/tests/acceptance/fixtures/snapshot_update"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  cp "$FIXTURES_DIR/snap.sh" "$WORKDIR/snap.sh"
  cp "$FIXTURES_DIR/ignore_colors.sh" "$WORKDIR/ignore_colors.sh"
  SNAPSHOT_ALPHA="$WORKDIR/snapshots/snap_sh.test_snapshot_alpha.snapshot"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function test_a_missing_snapshot_is_recorded_by_default() {
  local code=0
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file snap.sh) >/dev/null 2>&1 || code=$?

  assert_same "0" "$code"
  assert_file_exists "$SNAPSHOT_ALPHA"
}

function test_a_missing_snapshot_fails_with_no_snapshot_create() {
  local code=0
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --no-snapshot-create snap.sh 2>&1) || code=$?

  assert_not_same "0" "$code"
  assert_contains "snapshots/snap_sh.test_snapshot_alpha.snapshot" "$output"
  assert_file_not_exists "$SNAPSHOT_ALPHA"
}

function test_no_snapshot_create_also_covers_the_ignore_colors_assertion() {
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --no-snapshot-create ignore_colors.sh 2>&1) || true

  assert_contains "ignore_colors_sh.test_snapshot_without_colors.snapshot" "$output"
  assert_contains "failed" "$output"
}

function test_an_existing_snapshot_still_passes_with_no_snapshot_create() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file snap.sh) >/dev/null 2>&1 || true

  local code=0
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --no-snapshot-create snap.sh) >/dev/null 2>&1 || code=$?

  assert_same "0" "$code"
}

function test_env_variable_forbids_recording_too() {
  local code=0
  (cd "$WORKDIR" && BASHUNIT_SNAPSHOT_CREATE=false "$BASHUNIT_BIN" \
    --no-parallel --skip-env-file snap.sh) >/dev/null 2>&1 || code=$?

  assert_not_same "0" "$code"
  assert_file_not_exists "$SNAPSHOT_ALPHA"
}
