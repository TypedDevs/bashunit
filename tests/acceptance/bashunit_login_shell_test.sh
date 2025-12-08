#!/usr/bin/env bash

function test_login_flag_works_without_errors() {
  local output
  output=$(./bashunit --no-parallel --simple --login \
    tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1) || true

  assert_contains "All tests passed" "$output"
}

function test_login_flag_short_form_works() {
  local output
  output=$(./bashunit --no-parallel --simple -l \
    tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1) || true

  assert_contains "All tests passed" "$output"
}

function test_login_via_env_var() {
  local output
  output=$(BASHUNIT_LOGIN_SHELL=true \
    ./bashunit --no-parallel --simple \
    tests/acceptance/fixtures/test_bashunit_when_a_test_passes.sh 2>&1) || true

  assert_contains "All tests passed" "$output"
}
