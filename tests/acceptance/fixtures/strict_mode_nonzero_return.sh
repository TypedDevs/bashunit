#!/usr/bin/env bash

function test_uses_nonzero_return() {
  # This test uses a command that returns non-zero
  # In permissive mode: passes (non-zero exit is allowed)
  # In strict mode: fails (set -e causes test to abort)
  false
  assert_same "reached" "reached"
}
