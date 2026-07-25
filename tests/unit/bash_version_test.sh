#!/usr/bin/env bash

# The floor is 3.2, not 3.0: that is the bash macOS ships, and bash 3.0/3.1 lack
# `printf -v` and `+=`, and predate the 3.2 change to `[[ =~ ]]` quoting that
# makes regex matching behave consistently across supported versions.
# The gate used to compare only the major, so any 3.x was accepted.

function test_fail_with_bash_2() {
  local output
  local exit_code=0
  output=$(BASHUNIT_TEST_BASH_VERSION=2.05 ./bashunit --version 2>&1) || exit_code=$?
  assert_contains "Bashunit requires Bash >= 3.2. Current version: 2.05" "$output"
  assert_general_error "$output" "" "$exit_code"
}

function test_fail_with_bash_3_0() {
  local output
  local exit_code=0
  output=$(BASHUNIT_TEST_BASH_VERSION=3.0 ./bashunit --version 2>&1) || exit_code=$?
  assert_contains "Bashunit requires Bash >= 3.2. Current version: 3.0" "$output"
  assert_general_error "$output" "" "$exit_code"
}

function test_fail_with_bash_3_1() {
  local output
  local exit_code=0
  output=$(BASHUNIT_TEST_BASH_VERSION=3.1 ./bashunit --version 2>&1) || exit_code=$?
  assert_general_error "$output" "" "$exit_code"
}

function test_accepts_bash_3_2() {
  local exit_code=0
  BASHUNIT_TEST_BASH_VERSION=3.2 ./bashunit --version >/dev/null 2>&1 || exit_code=$?
  assert_successful_code "" "" "$exit_code"
}

function test_accepts_bash_4_and_newer() {
  local exit_code=0
  BASHUNIT_TEST_BASH_VERSION=5.2 ./bashunit --version >/dev/null 2>&1 || exit_code=$?
  assert_successful_code "" "" "$exit_code"
}
