#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_should_allow_test_drive_development() {
  local test_file=./tests/acceptance/fake_error_test.sh
  local fixture_start
  fixture_start=$(printf "Running ./tests/acceptance/fake_error_test.sh
\e[31m✗ Failed\e[0m: Error tdd
    \e[2m./tests/acceptance/fake_error_test.sh:")
  local fixture_end
  fixture_end=$(printf "\e[0m

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m0 failed\e[0m, 0 total")

  echo "
  #!/bin/bash
  function test_error_tdd() { assert_that_will_never_exist \"1\" \"1\" ; }" > $test_file

  set +e

  assert_contains "$fixture_start" "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_contains "$fixture_end" "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"

  rm $test_file
}

function test_bashunit_when_stop_on_failure() {
  local test_file=./tests/acceptance/fixtures/stop_on_failure.sh
  local expected_output
  expected_output=$(printf "Running %s
\e[32m✓ Passed\e[0m: A success
\e[31m✗ Failed\e[0m: B error
    \e[2mExpected\e[0m \e[1m\'1\'\e[0m
    \e[2mbut got\e[0m \e[1m\'2\'\e[0m" "$test_file")

  assert_contains "$expected_output" "$(./bashunit --env "$TEST_ENV_FILE" --stop-on-failure "$test_file")"
}
