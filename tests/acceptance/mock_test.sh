#!/bin/bash

#
# Make sure that the runner::clear_mocks() is being called and removing the mocks and spies
#
function test_runner_clear_mocks_first() {
  mock ls echo foo
  assert_equals "foo" "$(ls)"
}

function test_runner_clear_mocks_second() {
  assert_not_equals "foo" "$(ls)"
}
