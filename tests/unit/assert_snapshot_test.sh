#!/usr/bin/env bash

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
}

function test_successful_assert_match_snapshot() {
  assert_empty "$(assert_match_snapshot "Hello World!")"
}

function test_creates_a_snapshot() {
  local snapshot_file_path=tests/unit/snapshots/assert_snapshot_test_sh.test_creates_a_snapshot.snapshot
  local expected=$((_ASSERTIONS_SNAPSHOT + 1))

  assert_file_not_exists $snapshot_file_path

  assert_match_snapshot "Expected snapshot"

  assert_same "$expected" "$_ASSERTIONS_SNAPSHOT"
  assert_file_exists $snapshot_file_path
  assert_same "Expected snapshot" "$(cat $snapshot_file_path)"

  rm $snapshot_file_path
}

function test_unsuccessful_assert_match_snapshot() {
  local expected

  if dependencies::has_git; then
    expected="$(printf "✗ Failed: Unsuccessful assert match snapshot
    Expected to match the snapshot
    [-Actual-]{+Expected+} snapshot[-text-]")"
  else
    expected="$(printf "✗ Failed: Unsuccessful assert match snapshot
    Expected to match the snapshot")"
  fi

  local actual
  actual="$(assert_match_snapshot "Expected snapshot")"

  assert_equals "$expected" "$actual"
}
