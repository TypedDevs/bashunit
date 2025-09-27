#!/usr/bin/env bash

function test_fail_with_old_bash_version() {
  output=$(BASHUNIT_TEST_BASH_VERSION=2.9 ./bashunit --version 2>&1)
  exit_code=$?
  assert_contains "Bashunit requires Bash >= 3.0. Current version: 2.9" "$output"
  assert_general_error "$output" "" "$exit_code"
}

function test_pass_with_bash_3_0() {
  output=$(BASHUNIT_TEST_BASH_VERSION=3.0 ./bashunit --version 2>&1)
  exit_code=$?
  assert_successful_code "$output" "" "$exit_code"
}
