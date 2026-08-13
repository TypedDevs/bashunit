#!/usr/bin/env bash
set -euo pipefail

# A test driven by a @data_provider runs once per data set, but an unnamed
# snapshot is named after the test *function* -- so every data set shares one
# file. The first one to run creates it and the rest compare against its
# content and fail with "Expected to match the snapshot", which describes the
# symptom and hides the cause: the snapshot is shared, not wrong (#1185).
#
# The behaviour itself is deliberate -- the filename is documented as the test
# function's, and `assert_match_named_snapshot` gives one file per value. What
# was missing is any mention of the interaction, so this pins the behaviour and
# docs/assertions.md now warns about it.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(mktemp -d)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function provide_values() { echo "alpha"; echo "beta"; }'
    printf '%s\n' '# @data_provider provide_values'
    printf '%s\n' 'function test_shared_snapshot() { assert_match_snapshot "value is $1"; }'
  } >"$WORKDIR/p_test.sh"
}

function tear_down() {
  rm -rf "$WORKDIR"
}

function _run() {
  (cd "$WORKDIR" && "$BASHUNIT_BIN" --no-parallel p_test.sh 2>&1) || true
}

# The behaviour, pinned: the second data set fails against the first one's
# snapshot. Documented in docs/assertions.md, because the failure renderer has
# no signal for "this test ran with provider arguments" -- exposing one is a
# design change, not a message fix.
function test_a_second_data_set_fails_against_the_first_ones_snapshot() {
  _run >/dev/null # first run creates the snapshot for the first data set

  local output
  output="$(_run)"

  assert_contains "Expected to match the snapshot" "$output"
  assert_contains "1 passed" "$output"
}

# Only one file, which is the documented behaviour and stays that way: giving
# each data set its own would orphan every snapshot already on disk.
function test_one_snapshot_file_is_still_written_for_all_data_sets() {
  _run >/dev/null

  local count
  count=$(find "$WORKDIR/snapshots" -name '*.snapshot' | wc -l | tr -d ' ')

  assert_same 1 "$count"
}

# A test without a provider must not gain the hint.
function test_a_plain_test_mismatch_says_nothing_about_providers() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_plain() { assert_match_snapshot "$SNAP_VALUE"; }'
  } >"$WORKDIR/q_test.sh"

  (cd "$WORKDIR" && SNAP_VALUE=one "$BASHUNIT_BIN" --no-parallel q_test.sh >/dev/null 2>&1) || true

  local output
  output="$( (cd "$WORKDIR" && SNAP_VALUE=two "$BASHUNIT_BIN" --no-parallel q_test.sh 2>&1) || true)"

  assert_contains "snapshot" "$output"
  assert_not_contains "data provider" "$output"
}
