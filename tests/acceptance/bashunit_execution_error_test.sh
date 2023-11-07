#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_when_a_execution_error() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh
  local fixture_start
  fixture_start=$(printf "Running ./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh
\e[31m✗ Failed\e[0m: Error
    \e[2mExpected\e[0m \e[1m\'127\'\e[0m
    \e[2mto be exactly\e[0m \e[1m\'1\'\e[0m
\e[31m✗ Failed\e[0m: Error
    \e[2m./tests/acceptance/fixtures/test_bashunit_when_a_execution_error.sh:")
  local fixture_end
  fixture_end=$(printf "\e[0m

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m1 failed\e[0m, 1 total")

  todo "Add snapshots with regex to assert this test (part of the error message is localized)"
  todo "Add snapshots with simple/verbose modes as in bashunit_pass_test and bashunit_fail_test"

  assert_contains "$fixture_start" "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_contains "$fixture_end" "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
}
