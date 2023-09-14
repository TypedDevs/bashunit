#!/bin/bash

function test_bash_unit_when_a_test_passes() {
  local test_file=./tests/acceptance/fake_success_test.sh
  #local fixture_route="./tests/acceptance/fixtures/$_OS/assert_success"
  fixture=$(printf "Running ./tests/acceptance/fake_success_test.sh
\e[32m✓ Passed\e[0m: Succeed

\e[2mTests:     \e[0m \e[32m1 passed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[32m1 passed\e[0m, 1 total
\e[42mAll tests passed\e[0m")
  echo "
#!/bin/bash
function test_succeed() { assertEquals \"1\" \"1\" ; }" > $test_file

  assertContains\
   "$fixture"\
    "$(./bashunit "$test_file")"

  rm $test_file
}

function test_bash_unit_when_a_test_fail() {
  local test_file=./tests/acceptance/fake_fail_test.sh
  #local fixture_route="./tests/acceptance/fixtures/$_OS/assert_fail"
  fixture=$(printf "Running ./tests/acceptance/fake_fail_test.sh
\e[31m✗ Failed\e[0m: Fail
    \e[2mExpected\e[0m \e[1m'1'\e[0m
    \e[2mbut got\e[0m \e[1m'0'\e[0m

\e[2mTests:     \e[0m \e[31m1 failed\e[0m, 1 total
\e[2mAssertions:\e[0m \e[31m1 failed\e[0m, 1 total")
  echo "
#!/bin/bash
function test_fail() { assertEquals \"1\" \"0\" ; }" > $test_file

  assertContains\
   "$fixture"\
    "$(./bashunit "$test_file")"

  rm $test_file
}
