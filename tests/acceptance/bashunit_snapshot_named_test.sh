#!/usr/bin/env bash
set -euo pipefail

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
  FIXTURE="$(pwd)/tests/acceptance/fixtures/snapshot_named/named.sh"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  cp "$FIXTURE" "$WORKDIR/named.sh"
  SNAPSHOTS="$WORKDIR/snapshots"
  DEFAULT="$SNAPSHOTS/named_sh.test_named_snapshots.snapshot"
  FIRST="$SNAPSHOTS/named_sh.test_named_snapshots.first_value.snapshot"
  SAFE="$SNAPSHOTS/named_sh.test_named_snapshots._______second_.snapshot"
  COLORED="$SNAPSHOTS/named_sh.test_named_snapshots.colored.snapshot"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function test_named_snapshots_create_distinct_safe_files() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file named.sh) \
    >/dev/null 2>&1

  assert_same "default value" "$(<"$DEFAULT")"
  assert_same "named value" "$(<"$FIRST")"
  assert_same "safe value" "$(<"$SAFE")"
  assert_same "colored value" "$(<"$COLORED")"
}

function test_named_snapshot_mismatch_names_the_path_and_update_flag() {
  mkdir -p "$SNAPSHOTS"
  printf 'stale value\n' >"$FIRST"

  local output status=0
  output=$(cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    named.sh 2>&1) || status=$?

  assert_same 1 "$status"
  assert_contains "snapshots/named_sh.test_named_snapshots.first_value.snapshot" "$output"
  assert_contains "--snapshot-update" "$output"
}

function test_snapshot_update_rewrites_a_named_snapshot() {
  mkdir -p "$SNAPSHOTS"
  printf 'stale value\n' >"$FIRST"

  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel --skip-env-file \
    --snapshot-update named.sh) >/dev/null 2>&1

  assert_same "named value" "$(<"$FIRST")"
}
