#!/usr/bin/env bash

# Writes a file the framework never handed out, named with this test's own id
# so it matches the cleanup glob. Only a directory scan could find it.
function test_plants_a_file_it_created_itself() {
  printf 'planted\n' >"$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_TEST_ID}_planted"
  printf '%s\n' "$BASHUNIT_TEMP_DIR/${BASHUNIT_CURRENT_TEST_ID}_planted" >"$MARKER_SPY_PLANTED"
  assert_same 1 1
}

function test_uses_the_temp_file_helper() {
  local f
  f=$(bashunit::temp_file)
  printf '%s\n' "$f" >"$MARKER_SPY_HANDED"
  assert_file_exists "$f"
}
