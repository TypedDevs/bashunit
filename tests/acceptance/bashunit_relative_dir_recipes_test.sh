#!/usr/bin/env bash
set -euo pipefail

# The docs/globals.md recipes for working relative to the test file's own
# directory, run exactly as documented. The last fixture checks that a `cd` in
# set_up_before_script does not carry over to the next file.

function set_up_before_script() {
  D="./tests/acceptance/fixtures/relative_dir"
}

function _run_recipes() {
  ./bashunit --skip-env-file --no-color "$@" \
    "$D/source_relative_fixture.sh" "$D/cd_relative_fixture.sh" "$D/next_file_fixture.sh"
}

function test_recipes_pass_sequentially() {
  local output ec=0
  output=$(_run_recipes --no-parallel 2>&1) || ec=$?

  assert_same 0 "$ec"
  assert_contains "3 passed, 3 total" "$output"
}

function test_recipes_pass_in_parallel() {
  local output ec=0
  output=$(_run_recipes --parallel 2>&1) || ec=$?

  assert_same 0 "$ec"
  assert_contains "3 passed, 3 total" "$output"
}
