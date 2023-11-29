#!/bin/bash

function test_mock_ps_when_executing_a_script() {
  mock ps cat ./tests/functional/fixtures/doubles_ps_output

  assert_match_snapshot "$(./tests/functional/fixtures/doubles_script.sh)"
}

function test_mock_ps_when_executing_a_sourced_function() {
  source ./tests/functional/fixtures/doubles_function.sh
  mock ps cat ./tests/functional/fixtures/doubles_ps_output

  assert_match_snapshot "$(top_mem)"
}
