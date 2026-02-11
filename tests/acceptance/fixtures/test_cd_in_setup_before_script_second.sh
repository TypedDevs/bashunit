#!/usr/bin/env bash
set -euo pipefail

# Regression test for https://github.com/TypedDevs/bashunit/issues/532
# Second test file that should run after the first test changes directory

function test_second_file_runs() {
  assert_equals "second" "second"
}
