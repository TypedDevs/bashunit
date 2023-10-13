#!/bin/bash

function test_bashunit_when_a_test_passes_verbose_output() {
  local test_file=./tests/acceptance/fake_success_test.sh
  fixture=$(printf "Running ./tests/acceptance/fake_success_test.sh
\e[32m✓ Passed\e[0m: Succeed

\e[2mTests:     \e[0m \e[32m1 passed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[32m1 passed\e[0m, 1 total
\e[42mAll tests passed\e[0m")

  echo "
#!/bin/bash
function test_succeed() { assert_equals \"1\" \"1\" ; }" > $test_file

  assert_contains "$fixture" "$(./bashunit --verbose "$test_file")"
  assert_successful_code "$(./bashunit --verbose "$test_file")"

  rm $test_file
}

function test_bashunit_when_a_test_passes_simple_output() {
  local test_file=./tests/acceptance/fake_dots_test.sh
  local fixture
  fixture=$(printf "....
\e[2mTests:     \e[0m \e[32m4 passed\e[0m, 4 total
\e[2mAssertions:\e[0m \e[32m6 passed\e[0m, 6 total
\e[42mAll tests passed\e[0m")

  echo "
#!/bin/bash
function test_1() { assert_equals \"1\" \"1\" ; }
function test_2() { assert_equals \"1\" \"1\" ; assert_equals \"1\" \"1\" ;}
function test_3() { assert_equals \"1\" \"1\" ; assert_equals \"1\" \"1\" ; }
function test_4() { assert_equals \"1\" \"1\" ; }" > $test_file

  assert_contains "$fixture" "$(./bashunit "$test_file" --simple)"
  assert_successful_code "$(./bashunit "$test_file")"

  rm $test_file
}

function test_bashunit_when_a_test_fail() {
  local test_file=./tests/acceptance/fake_fail_test.sh
  fixture=$(printf "Running ./tests/acceptance/fake_fail_test.sh
\e[31m✗ Failed\e[0m: Fail
    \e[2mExpected\e[0m \e[1m\'1\'\e[0m
    \e[2mbut got\e[0m \e[1m\'0\'\e[0m

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m1 failed\e[0m, 1 total")

  echo "
#!/bin/bash
function test_fail() { assert_equals \"1\" \"0\" ; }" > $test_file

  assert_contains "$fixture" "$(./bashunit --verbose "$test_file")"
  assert_general_error "$(./bashunit --verbose "$test_file")"

  rm $test_file
}

function test_bashunit_when_a_test_execution_error() {
  local test_file=./tests/acceptance/fake_error_test.sh
  fixture=$(printf "Running ./tests/acceptance/fake_error_test.sh
\e[31m✗ Failed\e[0m: Error with error code 127

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m0 failed\e[0m, 0 total")

  echo "
#!/bin/bash
function test_error() {
  invalidFunctionName 2>/dev/null
  assertGeneralError
}" > $test_file

  set +e

  assertContains "$fixture" "$(./bashunit --verbose "$test_file")"
  assertGeneralError "$(./bashunit --verbose "$test_file")"

  rm $test_file
}

function test_bashunit_should_allow_test_drive_development() {
  local test_file=./tests/acceptance/fake_error_test.sh
  fixture=$(printf "Running ./tests/acceptance/fake_error_test.sh
\e[31m✗ Failed\e[0m: Error tdd with error code 127

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m0 failed\e[0m, 0 total")

  echo "
  #!/bin/bash
  function test_error_tdd() { assert_that_will_never_exist \"1\" \"1\" 2>/dev/null ; }" > $test_file

  set +e

  assertContains "$fixture" "$(./bashunit "$test_file")"
  assertGeneralError "$(./bashunit "$test_file")"

  rm $test_file
}

function test_bashunit_should_display_version() {
  local fixture
  fixture=$(printf "%s" "$BASHUNIT_VERSION")

  assert_contains "$fixture" "$(./bashunit --version)"
}
