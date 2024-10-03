#!/bin/bash
set -euo pipefail

function test_globals_current_dir() {
  assert_same "tests/unit" "$(current_dir)"
}

function test_globals_current_filename() {
  assert_same "globals_test.sh" "$(current_filename)"
}
