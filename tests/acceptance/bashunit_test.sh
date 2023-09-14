#!/bin/bash

function test_bash_unit_when_a_test_passes() {
  local test_file=./tests/acceptance/fake_success_test.sh
  local fixture_route=./tests/acceptance/fixtures/assert_success
  fixture=$(cat $fixture_route)
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
  local fixture_route=./tests/acceptance/fixtures/assert_fail
  fixture=$(cat $fixture_route)
  echo "
#!/bin/bash
function test_fail() { assertEquals \"1\" \"0\" ; }" > $test_file

  assertContains\
   "$fixture"\
    "$(./bashunit "$test_file")"
  rm $test_file
}
