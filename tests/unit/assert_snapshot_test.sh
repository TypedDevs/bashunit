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

function test_successful_assert_match_snapshot_ignore_colors() {
  local colored
  colored=$(printf '\e[31mHello\e[0m World!')
  assert_empty "$(assert_match_snapshot_ignore_colors "$colored")"
}

function test_creates_a_snapshot_ignore_colors() {
  local snapshot_file_path=tests/unit/snapshots/assert_snapshot_test_sh.test_creates_a_snapshot_ignore_colors.snapshot
  local expected=$((_ASSERTIONS_SNAPSHOT + 1))

  assert_file_not_exists $snapshot_file_path

  local colored
  colored=$(printf '\e[32mExpected\e[0m snapshot')

  assert_match_snapshot_ignore_colors "$colored"

  assert_same "$expected" "$_ASSERTIONS_SNAPSHOT"
  assert_file_exists $snapshot_file_path
  assert_same "Expected snapshot" "$(cat $snapshot_file_path)"

  rm $snapshot_file_path
}

function test_unsuccessful_assert_match_snapshot_ignore_colors() {
  local expected

  if dependencies::has_git; then
    expected="$(printf "✗ Failed: Unsuccessful assert match snapshot ignore colors
    Expected to match the snapshot
    [-Actual-]{+Expected+} snapshot[-text-]")"
  else
    expected="$(printf "✗ Failed: Unsuccessful assert match snapshot ignore colors
    Expected to match the snapshot")"
  fi

  local actual
  local colored
  colored=$(printf '\e[31mExpected snapshot\e[0m')
  actual="$(assert_match_snapshot_ignore_colors "$colored")"

  assert_equals "$expected" "$actual"
}

function test_assert_match_snapshot_with_placeholder() {
  local snapshot_file_path
  snapshot_file_path=tests/unit/snapshots/assert_snapshot_test_sh.test_assert_match_snapshot_with_placeholder.snapshot
  mkdir -p tests/unit/snapshots
  echo 'Run at ::ignore::' > "$snapshot_file_path"

  assert_empty "$(assert_match_snapshot "Run at $(date)")"

  rm "$snapshot_file_path"
}
