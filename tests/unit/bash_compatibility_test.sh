#!/usr/bin/env bash

# Bash 3.0 does not expand a compound array assignment attached to `local`:
# `local arr=(a b)` stores the literal string "(a b)" as a single element
# instead of building the array. Every bash >= 3.2 does the right thing, so
# this only ever breaks on the Bash 3.0 jobs, and silently (see #764).
# Declare and assign on separate lines instead:
#
#   local arr
#   arr=(a b)
#
function test_src_has_no_compound_array_assignment_attached_to_local() {
  local offenders
  offenders=$(grep -rnE '^[[:space:]]*local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=\(' src/ || true)

  assert_empty "$offenders"
}
