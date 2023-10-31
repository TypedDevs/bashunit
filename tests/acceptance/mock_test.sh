#!/bin/bash

#
# Make sure that the runner::clear_mocks() is being called and removing the mocks and spies
#
function test_runner_clear_mocks_1() {
  mock ls echo foo
  assert_is_mock ls

  spy ps
  assert_is_mock ps
}

function test_runner_clear_mocks_2() {
  assert_is_not_mock ls
  assert_is_not_mock ps
}
