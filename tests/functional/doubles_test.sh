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

function test_spy_commands_called_when_executing_a_script() {
  spy ps
  spy awk
  spy head

  ./tests/functional/fixtures/doubles_script.sh

  assert_have_been_called ps
  assert_have_been_called awk
  assert_have_been_called head
}

function test_spy_commands_called_when_executing_a_sourced_function() {
  source ./tests/functional/fixtures/doubles_function.sh
  spy ps
  spy awk
  spy head

  top_mem

  assert_have_been_called ps
  assert_have_been_called awk
  assert_have_been_called head
}

function test_spy_commands_called_once_when_executing_a_script() {
  spy ps
  spy awk
  spy head

  ./tests/functional/fixtures/doubles_script.sh

  assert_have_been_called_times 1 ps
  assert_have_been_called_times 1 awk
  assert_have_been_called_times 1 head
}

function test_spy_commands_called_once_when_executing_a_sourced_function() {
  source ./tests/functional/fixtures/doubles_function.sh
  spy ps
  spy awk
  spy head

  top_mem

  assert_have_been_called_times 1 ps
  assert_have_been_called_times 1 awk
  assert_have_been_called_times 1 head
}
