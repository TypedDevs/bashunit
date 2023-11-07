#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
  TEST_ENV_FILE_SIMPLE="tests/acceptance/fixtures/.env.simple"
}

function test_bashunit_when_a_test_passes_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_a_test_passes_verbose_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
}

function test_bashunit_when_a_test_passes_simple_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
}

function test_bashunit_when_a_test_passes_simple_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
  assert_successful_code "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
}

function test_bashunit_when_a_test_fail_verbose_output_env() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
}

function test_bashunit_when_a_test_fail_verbose_output_option() {
  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file" --verbose)"
}

function test_bashunit_when_a_test_fail_simple_output_env() {
  todo "Should print something like ...F."
  return

  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE_SIMPLE" "$test_file")"
}

function test_bashunit_when_a_test_fail_simple_output_option() {
  todo "Should print something like ...F."
  return

  local test_file=./tests/acceptance/fixtures/test_bashunit_when_a_test_fail.sh

  assert_match_snapshot "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file" --simple)"
}

function test_bashunit_when_a_test_execution_error() {
  local test_file=./tests/acceptance/fake_error_test.sh
  local fixture_start
  fixture_start=$(printf "Running ./tests/acceptance/fake_error_test.sh
\e[31m✗ Failed\e[0m: Error
    \e[2mExpected\e[0m \e[1m\'127\'\e[0m
    \e[2mto be exactly\e[0m \e[1m\'1\'\e[0m
\e[31m✗ Failed\e[0m: Error
    \e[2m./tests/acceptance/fake_error_test.sh:")
  local fixture_end
  fixture_end=$(printf "\e[0m

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m1 failed\e[0m, 1 total")

  echo "
#!/bin/bash
function test_error() {
  invalid_function_name
  assert_general_error
}" > $test_file

  set +e

  assert_contains "$fixture_start" "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_contains "$fixture_end" "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"
  assert_general_error "$(./bashunit --env "$TEST_ENV_FILE" "$test_file")"

  rm $test_file
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

function test_bashunit_should_display_version() {
  local fixture
  fixture=$(printf "%s" "$BASHUNIT_VERSION")

  assert_contains "$fixture" "$(./bashunit --version)"
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
