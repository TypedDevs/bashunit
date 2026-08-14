#!/usr/bin/env bash
# shellcheck disable=SC2317

set -euo pipefail

# `-e/--env/--boot` reported "cannot read the bootstrap file" for four
# different causes and it was true of one: a directory *is* readable -- the
# check that rejects it is -f, not -r -- a missing path is not there at all,
# and /dev/null is readable but not a regular file (#1262).
#
# These live apart from bashunit_init_test.sh on purpose: the unreadable case
# can only be set up with chmod, which is a no-op for root, so it skips on the
# Bash 3.0 CI image -- and bashunit_summary_output_test.sh asserts that file
# has exactly one skipped test.

BASHUNIT_PATH="$PWD/bashunit"

function set_up() {
  TMP_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TMP_DIR"
}

# One message covered three different causes, and was true of only one: a
# directory *is* readable -- the check that rejects it is -f, not -r -- and for
# a missing path "cannot read" understates "is not there" (#1262).
function test_a_bootstrap_that_does_not_exist_says_so() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env nope.sh t_test.sh 2>&1) || true
  popd >/dev/null

  assert_contains "does not exist" "$output"
}

function test_a_bootstrap_that_is_a_directory_says_so() {
  pushd "$TMP_DIR" >/dev/null
  mkdir -p boot_dir
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env boot_dir t_test.sh 2>&1) || true
  popd >/dev/null

  assert_contains "is a directory" "$output"
}

# Readable, but not a regular file. /dev/null exists everywhere the suite runs.
function test_a_bootstrap_that_is_not_a_regular_file_says_so() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh

  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env /dev/null t_test.sh 2>&1) || true
  popd >/dev/null

  assert_contains "not a regular file" "$output"
}

# The remaining case keeps the original wording, which is accurate for it. Root
# can read a mode-000 file, so ask the kernel rather than assume.
function test_an_unreadable_bootstrap_still_says_cannot_read() {
  pushd "$TMP_DIR" >/dev/null
  printf 'function test_ok() { assert_same 1 1; }\n' >t_test.sh
  : >unread.sh
  chmod 000 unread.sh
  if [ -r unread.sh ]; then
    chmod 644 unread.sh
    popd >/dev/null
    bashunit::skip "the current user can read a mode-000 file" && return
  fi

  local output
  output=$("$BASHUNIT_PATH" --no-parallel --env unread.sh t_test.sh 2>&1) || true
  chmod 644 unread.sh
  popd >/dev/null

  assert_contains "cannot read the bootstrap file" "$output"
}
