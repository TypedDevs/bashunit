#!/usr/bin/env bash

# shellcheck disable=SC2329 # Test functions are invoked indirectly by bashunit

############################
# bashunit::watch::_poll_changes
############################

function test_poll_changes_detects_sh_file_newer_than_sentinel() {
  local dir
  dir=$(bashunit::temp_dir watch_poll_new)
  local sentinel="$dir/.sentinel"
  : >"$sentinel"
  touch -t 202001010000 "$sentinel"
  : >"$dir/foo.sh"
  touch -t 202501010000 "$dir/foo.sh"

  assert_not_empty "$(bashunit::watch::_poll_changes "$sentinel" "$dir")"
}

function test_poll_changes_reports_nothing_when_no_sh_changed() {
  local dir
  dir=$(bashunit::temp_dir watch_poll_none)
  : >"$dir/foo.sh"
  touch -t 202001010000 "$dir/foo.sh"
  local sentinel="$dir/.sentinel"
  : >"$sentinel"
  touch -t 202501010000 "$sentinel"

  assert_empty "$(bashunit::watch::_poll_changes "$sentinel" "$dir")"
}

function test_poll_changes_ignores_non_sh_files() {
  local dir
  dir=$(bashunit::temp_dir watch_poll_nonsh)
  local sentinel="$dir/.sentinel"
  : >"$sentinel"
  touch -t 202001010000 "$sentinel"
  : >"$dir/note.txt"
  touch -t 202501010000 "$dir/note.txt"

  assert_empty "$(bashunit::watch::_poll_changes "$sentinel" "$dir")"
}

############################
# bashunit::env::positive_int_or_default
############################

function test_positive_int_or_default_keeps_valid_integer() {
  assert_equals "5" "$(bashunit::env::positive_int_or_default 5 2)"
}

function test_positive_int_or_default_falls_back_on_zero() {
  assert_equals "2" "$(bashunit::env::positive_int_or_default 0 2)"
}

function test_positive_int_or_default_falls_back_on_non_numeric() {
  assert_equals "2" "$(bashunit::env::positive_int_or_default abc 2)"
}

function test_positive_int_or_default_falls_back_on_empty() {
  assert_equals "2" "$(bashunit::env::positive_int_or_default '' 2)"
}
