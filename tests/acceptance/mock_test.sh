#!/usr/bin/env bash
set -euo pipefail

#
# Make sure that the `bashunit::runner::clear_mocks()` is being called,
# removing the mocks and spies from the first test
#
function test_runner_clear_mocks_first() {
  bashunit::mock ls echo foo
  assert_same "foo" "$(ls)"

  bashunit::spy ps
  ps foo bar
  assert_have_been_called_times 1 ps
}

function test_runner_clear_mocks_second() {
  assert_not_equals "foo" "$(ls)"
  assert_have_been_called_times 0 ps
}
