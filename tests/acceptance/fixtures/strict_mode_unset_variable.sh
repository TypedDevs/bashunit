#!/usr/bin/env bash

function test_uses_unset_variable() {
  # This test uses an undefined variable
  # In permissive mode: passes (empty string substitution)
  # In strict mode: fails (set -u causes error)
  local result="prefix_${UNDEFINED_VAR}_suffix"
  assert_same "prefix__suffix" "$result"
}
