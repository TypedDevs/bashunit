#!/usr/bin/env bash
# shellcheck disable=SC2155

function set_up() {
  export BASHUNIT_SIMPLE_OUTPUT=false
  unset BASHUNIT_SNAPSHOT_PLACEHOLDER
}

function test_successful_assert_match_snapshot() {
  assert_empty "$(assert_match_snapshot "Hello World!")"
}

function test_creates_a_snapshot() {
  local snapshot_path="$(temp_dir)/assert_snapshot_test_sh.test_creates_a_snapshot.snapshot"
  local expected=$((_ASSERTIONS_SNAPSHOT + 1))

  assert_file_not_exists "$snapshot_path"
  assert_match_snapshot "Expected snapshot" "$snapshot_path"

  assert_same "$expected" "$_ASSERTIONS_SNAPSHOT"
  assert_file_exists "$snapshot_path"
  assert_same "Expected snapshot" "$(cat "$snapshot_path")"
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

  local actual="$(assert_match_snapshot "Expected snapshot")"

  assert_equals "$expected" "$actual"
}

function test_successful_assert_match_snapshot_ignore_colors() {
  local colored=$(printf '\e[31mHello\e[0m World!')
  assert_empty "$(assert_match_snapshot_ignore_colors "$colored")"
}

function test_creates_a_snapshot_ignore_colors() {
  local snapshot_path="$(temp_dir)/assert_snapshot_test_sh.test_creates_a_snapshot_ignore_colors.snapshot"
  local expected=$((_ASSERTIONS_SNAPSHOT + 1))

  assert_file_not_exists "$snapshot_path"
  local colored=$(printf '\e[32mExpected\e[0m snapshot')
  assert_match_snapshot_ignore_colors "$colored" "$snapshot_path"

  assert_same "$expected" "$_ASSERTIONS_SNAPSHOT"
  assert_file_exists "$snapshot_path"
  assert_same "Expected snapshot" "$(cat "$snapshot_path")"
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

  local colored=$(printf '\e[31mExpected snapshot\e[0m')
  local actual="$(assert_match_snapshot_ignore_colors "$colored")"

  assert_equals "$expected" "$actual"
}

function test_assert_match_snapshot_with_placeholder() {
  if ! dependencies::has_perl; then
    skip "perl not available" && return
  fi

  local snapshot_path="$(temp_dir)/assert_snapshot_test_sh.test_assert_match_snapshot_with_placeholder.snapshot"
  echo 'Run at ::ignore::' > "$snapshot_path"

  assert_empty "$(assert_match_snapshot "Run at $(date -u '+%F %T UTC')" "$snapshot_path")"
}

function test_assert_match_snapshot_with_custom_placeholder() {
  if ! dependencies::has_perl; then
    skip "perl not available" && return
  fi

  local snapshot_path="$(temp_dir)/assert_snapshot_test_sh.test_assert_match_snapshot_with_custom_placeholder.snapshot"
  echo 'Value __ANY__' > "$snapshot_path"

  export BASHUNIT_SNAPSHOT_PLACEHOLDER='__ANY__'
  assert_empty "$(assert_match_snapshot "Value 42" "$snapshot_path")"
}

function test_assert_match_snapshot_with_placeholder_without_perl() {
  mock dependencies::has_perl mock_false

  local snapshot_path
  snapshot_path="$(temp_dir)/assert_snapshot_test_sh.test_assert_match_snapshot_with_placeholder_without_perl.snapshot"
  echo 'Value __ANY__' > "$snapshot_path"

  export BASHUNIT_SNAPSHOT_PLACEHOLDER='__ANY__'
  assert_empty "$(assert_match_snapshot "Value 42" "$snapshot_path")"
}
