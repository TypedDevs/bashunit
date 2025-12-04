#!/usr/bin/env bash
set -euo pipefail

# Regression test for https://github.com/TypedDevs/bashunit/issues/532
# First test file that changes directory in set_up_before_script

function set_up_before_script() {
  cd "$(temp_dir)" || return 1
}

function test_first_file_runs() {
  assert_equals "first" "first"
}
