#!/usr/bin/env bash

function test_fail_with_old_bash_version() {
  local output
  local exit_code=0
  output=$(BASHUNIT_TEST_BASH_VERSION=2.05 ./bashunit --version 2>&1) || exit_code=$?
  assert_contains "Bashunit requires Bash >= 3.0. Current version: 2.05" "$output"
  assert_general_error "$output" "" "$exit_code"
}
