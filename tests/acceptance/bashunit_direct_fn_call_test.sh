#!/bin/bash

function set_up_before_script() {
  TEST_ENV_FILE="tests/acceptance/fixtures/.env.default"
}

function test_bashunit_direct_fn_call_passes() {
  local expected="foo"
  local actual="foo"

  ./bashunit -a assert_equals --env "$TEST_ENV_FILE" "$expected" $actual
  assert_successful_code
}

function test_bashunit_direct_fn_call_failure() {
  local expected="foo"
  local actual="bar"

  assert_match_snapshot "$(./bashunit -a assert_equals --env "$TEST_ENV_FILE" "$expected" $actual)"
  assert_general_error "$(./bashunit -a assert_equals --env "$TEST_ENV_FILE" "$expected" $actual)"
}
