#!/usr/bin/env bash

function function_being_tested() {
  if [ "$#" -lt 3 ]; then
    echo "function_being_tested requires at least 3 arguments." >&2
    return 1
  fi

  return 0
}

function test_assertion_failure_with_stderr_output() {
  function_being_tested 1 2

  assert_exit_code 0
}
