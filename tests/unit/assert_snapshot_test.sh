#!/bin/bash

function test_successful_assert_match_snapshot() {
  assert_empty "$(assert_match_snapshot "Hello World!")"
}

function test_creates_a_snapshot() {
  local snapshot_file_path=tests/unit/snapshots/assert_snapshot_test_sh.test_creates_a_snapshot.snapshot

  assert_file_not_exists $snapshot_file_path

  assert_match_snapshot "Expected snapshot"

  assert_file_exists $snapshot_file_path
  assert_equals "Expected snapshot" "$(cat $snapshot_file_path)"

  rm $snapshot_file_path
}

function test_unsuccessful_assert_match_snapshot() {
  local expected
  expected="$(printf "✗ Failed: Unsuccessful assert match snapshot
    Expected to match the snapshot
    [-Actual-]{+Expected+} snapshot[-text-]")"

  local actual
  actual="$(assert_match_snapshot "Expected snapshot")"
  actual_without_colors=$(echo -e "$actual" | sed "s/\x1B\[[0-9;]*[JKmsu]//g")

  assert_equals "$expected" "$actual_without_colors"
}
