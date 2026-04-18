#!/usr/bin/env bash

# shellcheck disable=SC2329 # Test functions are invoked indirectly by bashunit

############################
# bashunit::main::watch_get_checksum
############################

function test_checksum_is_stable_for_unchanged_paths() {
  local dir
  dir=$(bashunit::temp_dir watch_stable)
  : >"$dir/foo.sh"

  local first second
  first=$(bashunit::main::watch_get_checksum "$dir")
  second=$(bashunit::main::watch_get_checksum "$dir")

  assert_equals "$first" "$second"
}

function test_checksum_changes_when_file_mtime_changes() {
  local dir
  dir=$(bashunit::temp_dir watch_change)
  local file="$dir/foo.sh"
  : >"$file"
  touch -t 202001010000 "$file"

  local before after
  before=$(bashunit::main::watch_get_checksum "$dir")
  touch -t 202501010000 "$file"
  after=$(bashunit::main::watch_get_checksum "$dir")

  assert_not_equals "$before" "$after"
}

function test_checksum_differs_when_new_file_appears() {
  local dir
  dir=$(bashunit::temp_dir watch_new_file)
  : >"$dir/a.sh"

  local before after
  before=$(bashunit::main::watch_get_checksum "$dir")
  : >"$dir/b.sh"
  after=$(bashunit::main::watch_get_checksum "$dir")

  assert_not_equals "$before" "$after"
}

function test_checksum_ignores_non_sh_files() {
  local dir
  dir=$(bashunit::temp_dir watch_non_sh)
  : >"$dir/keep.sh"

  local before after
  before=$(bashunit::main::watch_get_checksum "$dir")
  : >"$dir/ignored.txt"
  : >"$dir/ignored.md"
  after=$(bashunit::main::watch_get_checksum "$dir")

  assert_equals "$before" "$after"
}

function test_checksum_handles_single_file_path() {
  local dir
  dir=$(bashunit::temp_dir watch_file)
  local file="$dir/single.sh"
  : >"$file"
  touch -t 202001010000 "$file"

  local before after
  before=$(bashunit::main::watch_get_checksum "$file")
  touch -t 202501010000 "$file"
  after=$(bashunit::main::watch_get_checksum "$file")

  assert_not_equals "$before" "$after"
}

function test_checksum_is_empty_for_missing_path() {
  local missing="/nonexistent/path/$$/xyz"

  assert_empty "$(bashunit::main::watch_get_checksum "$missing")"
}
