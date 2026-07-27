#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FIXTURES_DIR="$(pwd)/tests/acceptance/fixtures/snapshot_update"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  cp "$FIXTURES_DIR/snap.sh" "$WORKDIR/snap.sh"
  cp "$FIXTURES_DIR/placeholder.sh" "$WORKDIR/placeholder.sh"
  mkdir -p "$WORKDIR/snapshots"
  SNAPSHOT_ALPHA="$WORKDIR/snapshots/snap_sh.test_snapshot_alpha.snapshot"
  SNAPSHOT_BETA="$WORKDIR/snapshots/snap_sh.test_snapshot_beta.snapshot"
  echo "stale alpha" >"$SNAPSHOT_ALPHA"
  echo "stale beta" >"$SNAPSHOT_BETA"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function test_snapshot_update_rewrites_the_existing_snapshot() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-update snap.sh) >/dev/null 2>&1 || true

  assert_same "alpha value" "$(cat "$SNAPSHOT_ALPHA")"
  assert_same "beta value" "$(cat "$SNAPSHOT_BETA")"
}

function test_snapshot_update_composes_with_filter() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-update --filter alpha snap.sh) >/dev/null 2>&1 || true

  assert_same "alpha value" "$(cat "$SNAPSHOT_ALPHA")"
  assert_same "stale beta" "$(cat "$SNAPSHOT_BETA")"
}

function test_snapshot_update_reports_the_rewrite_instead_of_a_pass() {
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-update snap.sh 2>&1) || true

  assert_contains "Some snapshots updated" "$output"
  assert_contains "2 snapshot" "$output"
  assert_not_contains "2 passed" "$output"
}

function test_env_variable_updates_snapshots_too() {
  (cd "$WORKDIR" && BASHUNIT_SNAPSHOT_UPDATE=true "$BASHUNIT_BIN" \
    --no-parallel --skip-env-file snap.sh) >/dev/null 2>&1 || true

  assert_same "alpha value" "$(cat "$SNAPSHOT_ALPHA")"
}

function test_without_the_flag_a_stale_snapshot_still_fails() {
  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file snap.sh 2>&1) || true

  assert_contains "failed" "$output"
  assert_same "stale alpha" "$(cat "$SNAPSHOT_ALPHA")"
}

function test_a_snapshot_holding_a_placeholder_is_not_overwritten() {
  local snapshot="$WORKDIR/snapshots/placeholder_sh.test_snapshot_with_placeholder.snapshot"
  echo "run at ::ignore::" >"$snapshot"

  local output
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-update placeholder.sh 2>&1) || true

  assert_same "run at ::ignore::" "$(cat "$snapshot")"
  assert_contains "placeholder" "$output"
}

function test_snapshot_update_still_records_a_missing_snapshot() {
  rm -f "$SNAPSHOT_ALPHA"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-update --filter alpha snap.sh) >/dev/null 2>&1 || true

  assert_same "alpha value" "$(cat "$SNAPSHOT_ALPHA")"
}
