#!/usr/bin/env bash

# Both the script hook and the test body write the marker: --list must run
# neither, so its absence proves more than a test-body-only fixture would.
function set_up_before_script() {
  touch "$(dirname "${BASH_SOURCE[0]}")/.marker"
}

function test_writes_a_marker() {
  touch "$(dirname "${BASH_SOURCE[0]}")/.marker"
  assert_true true
}
