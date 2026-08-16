#!/usr/bin/env bash
set -euo pipefail

# `learn` shipped for nine months, so an upgrade can meet a script or a habit
# that still calls it. Without this it hits the generic path error, which reads
# like a bug in the caller rather than a command that is gone.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function test_learn_says_it_was_removed_and_points_at_the_docs() {
  local ec=0
  local output
  output=$("$BASHUNIT_BIN" learn 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "was removed" "$output"
  assert_contains "https://bashunit.com" "$output"
}
